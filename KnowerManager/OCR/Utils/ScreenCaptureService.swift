import Foundation
import AppKit
import ScreenCaptureKit

class ScreenCaptureService {
    private var currentTask: Process?
    // Ссылка на настройки для удобства
    private let settings = SettingsManager.shared
    
    // Гарантирует ровно один resume continuation (защита от двойного вызова
    // и от вечного ожидания, если процесс не завершится).
    private final class ContinuationState: @unchecked Sendable {
        private let lock = NSLock()
        // Состояние защищено NSLock, поэтому изоляция актора не нужна.
        nonisolated(unsafe) private var resumed = false
        nonisolated func claim() -> Bool {
            lock.lock(); defer { lock.unlock() }
            if resumed { return false }
            resumed = true
            return true
        }
    }
    
    // MARK: - Запрос разрешений
    
    @MainActor
        func requestPermissions() async -> Bool {
            // Для macOS 13.0+ (ScreenCaptureKit)
            if #available(macOS 13.0, *) {
                do {
                    // Пытаемся получить доступ к контенту экрана
                    // Этот метод async, поэтому здесь await нужен
                    _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                    return true
                } catch {
                    // Ошибка (нет прав) -> просто возвращаем false без алерта
                    return false
                }
            } else {
                // Для более старых версий (CGWindowList)
                let hasPermission = CGPreflightScreenCaptureAccess()
                if !hasPermission {
                    // Запрашиваем права (системный диалог macOS сам появится)
                    let granted = CGRequestScreenCaptureAccess()
                    return granted
                }
                return true
            }
        }

        private func openSystemSettings() {
            let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }
    
    // MARK: - Основные методы захвата
    
    func captureScreen() async throws -> NSImage? {
        guard await requestPermissions() else {
            throw ScreenCaptureError.permissionDenied
        }
        
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("capture_\(UUID().uuidString).png")
        
        return try await withCheckedThrowingContinuation { continuation in
            let state = ContinuationState()
            DispatchQueue.main.async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                task.arguments = ["-x", tempFile.path] // -x = без звука
                
                self.currentTask = task
                
                task.terminationHandler = { process in
                    DispatchQueue.main.async {
                        guard state.claim() else { return }
                        self.handleCaptureCompletion(
                            process: process,
                            tempFile: tempFile,
                            continuation: continuation
                        )
                    }
                }
                
                // Сначала скрываем окна (безопасный метод через orderOut)
                self.minimizeAllWindows()
                
                // Небольшая задержка, чтобы окна успели исчезнуть
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    do {
                        try task.run()
                    } catch {
                        if state.claim() { continuation.resume(throwing: error) }
                        return
                    }
                    // Страховка: если процесс почему-то не завершится, не висим вечно.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                        guard state.claim() else { return }
                        if task.isRunning { task.terminate() }
                        self.currentTask = nil
                        self.restoreAllWindows()
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
    
    func captureSelectedArea() async throws -> NSImage? {
        guard await requestPermissions() else {
            throw ScreenCaptureError.permissionDenied
        }
        
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("capture_area_\(UUID().uuidString).png")
        
        return try await withCheckedThrowingContinuation { continuation in
            let state = ContinuationState()
            DispatchQueue.main.async {
                self.minimizeAllWindows()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    let task = Process()
                    task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                    task.arguments = ["-i", "-x", tempFile.path] // -i = интерактивно (область)
                    
                    self.currentTask = task
                    
                    task.terminationHandler = { process in
                        DispatchQueue.main.async {
                            guard state.claim() else { return }
                            self.handleCaptureCompletion(
                                process: process,
                                tempFile: tempFile,
                                continuation: continuation
                            )
                        }
                    }
                    
                    do {
                        try task.run()
                    } catch {
                        if state.claim() { continuation.resume(throwing: error) }
                        return
                    }
                    // Интерактивный захват ждёт пользователя — даём щедрый таймаут.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 300) {
                        guard state.claim() else { return }
                        if task.isRunning { task.terminate() }
                        self.currentTask = nil
                        self.restoreAllWindows()
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
    
    // MARK: - Вспомогательные методы
    
    private func minimizeAllWindows() {
        for window in NSApplication.shared.windows {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                window.animator().alphaValue = 0.0
            } completionHandler: {
                window.orderOut(nil)
                window.alphaValue = 1.0
            }
        }
    }
    
    private func restoreAllWindows() {
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
            
            for window in NSApplication.shared.windows {
                if !window.isVisible {
                    window.makeKeyAndOrderFront(nil)
                    window.alphaValue = 1.0
                }
            }
        }
    }
    
    private func handleCaptureCompletion(
        process: Process,
        tempFile: URL,
        continuation: CheckedContinuation<NSImage?, Error>
    ) {
        restoreAllWindows()
        self.currentTask = nil
        
        if process.terminationStatus == 0 {
            if FileManager.default.fileExists(atPath: tempFile.path),
               let image = NSImage(contentsOf: tempFile) {
                try? FileManager.default.removeItem(at: tempFile)
                continuation.resume(returning: image)
            } else {
                try? FileManager.default.removeItem(at: tempFile)
                continuation.resume(returning: nil)
            }
        } else {
            try? FileManager.default.removeItem(at: tempFile)
            continuation.resume(returning: nil)
        }
    }
    
    func cancelCapture() {
        currentTask?.terminate()
        currentTask = nil
        restoreAllWindows()
    }
    
    func getImageFromClipboard() -> NSImage? {
        guard let data = NSPasteboard.general.data(forType: .tiff) else {
            return nil
        }
        return NSImage(data: data)
    }
    
    // MARK: - Debug
    
    func debugCaptureScreen() -> NSImage? {
        let task = Process()
        let pipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-x", "-c"]
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if let data = NSPasteboard.general.data(forType: .tiff) {
                return NSImage(data: data)
            }
        } catch {
            AppLogger.shared.debug("Debug capture error: \(error)")
        }
        
        return nil
    }
}

// MARK: - Ошибки (Локализованные)

enum ScreenCaptureError: LocalizedError {
    case permissionDenied
    case captureFailed
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return SettingsManager.shared.t(.scErrPermission) // LOCALIZED
        case .captureFailed:
            return SettingsManager.shared.t(.scErrFailed)     // LOCALIZED
        case .cancelled:
            return SettingsManager.shared.t(.scErrCancelled)  // LOCALIZED
        }
    }
}
