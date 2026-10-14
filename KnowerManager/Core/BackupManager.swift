import Foundation
import AppKit

// MARK: - Резервное копирование данных приложения
//
// Данные приложения хранятся в Application Support/KnowerManager:
//   • profiles.json       — VPN-профили
//   • subscriptions.json  — подписки
//   • ocr_history.json    — история распознаваний
//
// Копия создаётся/восстанавливается утилитой `ditto` (входит в состав macOS),
// которая корректно упаковывает и распаковывает ZIP.

enum BackupManager {

    /// Папка с данными приложения.
    static var dataDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return appSupport.appendingPathComponent("KnowerManager", isDirectory: true)
    }

    /// Имена файлов, участвующих в резервной копии.
    static let knownFileNames = ["profiles.json", "subscriptions.json", "ocr_history.json"]

    /// Рекомендуемое имя архива для NSSavePanel.
    static func suggestedFileName() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmm"
        return "KnowerManager-Backup-\(f.string(from: Date())).zip"
    }

    /// Создаёт ZIP-архив с данными приложения.
    /// - Parameter destination: путь к создаваемому архиву.
    static func createBackup(to destination: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: dataDirectory, withIntermediateDirectories: true)

        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }

        // --keepParent сохраняет верхнюю папку KnowerManager внутри архива.
        try runDitto(arguments: [
            "-c", "-k", "--sequesterRsrc", "--keepParent",
            dataDirectory.path,
            destination.path
        ])
    }

    /// Восстанавливает данные из ZIP-архива и перезагружает сервисы.
    @MainActor
    static func restoreBackup(from archive: URL) throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory
            .appendingPathComponent("KnowerRestore-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: temp) }

        try runDitto(arguments: ["-x", "-k", archive.path, temp.path])

        // Архив мог быть создан с --keepParent (тогда внутри есть папка KnowerManager)
        // или без него (файлы лежат в корне).
        let nested = temp.appendingPathComponent("KnowerManager", isDirectory: true)
        var sourceDir = temp
        if fm.fileExists(atPath: nested.appendingPathComponent("profiles.json").path) ||
           fm.fileExists(atPath: nested.appendingPathComponent("subscriptions.json").path) ||
           fm.fileExists(atPath: nested.appendingPathComponent("ocr_history.json").path) {
            sourceDir = nested
        }

        try fm.createDirectory(at: dataDirectory, withIntermediateDirectories: true)

        var restoredCount = 0
        for name in knownFileNames {
            let src = sourceDir.appendingPathComponent(name)
            guard fm.fileExists(atPath: src.path) else { continue }
            let dst = dataDirectory.appendingPathComponent(name)
            if fm.fileExists(atPath: dst.path) { try fm.removeItem(at: dst) }
            try fm.copyItem(at: src, to: dst)
            restoredCount += 1
        }

        guard restoredCount > 0 else { throw BackupError.emptyArchive }

        reloadServices()

        // Если приложение подключено, профили могли поменяться — отключаемся,
        // чтобы не работать с устаревшим процессом.
        XrayService.shared.stop()
    }

    /// Перезагружает данные из восстановленных файлов.
    @MainActor
    private static func reloadServices() {
        XrayService.shared.reloadFromDisk()
        SubscriptionManager.shared.reloadFromDisk()
        OCRManager.shared.reloadHistoryFromDisk()
    }

    // MARK: - Private

    private static func runDitto(arguments: [String]) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        task.arguments = arguments
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        try task.run()
        task.waitUntilExit()
        if task.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw BackupError.commandFailed(message.isEmpty ? "ditto exit \(task.terminationStatus)" : message)
        }
    }
}

enum BackupError: LocalizedError {
    case commandFailed(String)
    case emptyArchive

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return message
        case .emptyArchive:
            return "Архив не содержит файлов данных Knower Manager."
        }
    }
}
