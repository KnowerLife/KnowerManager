import SwiftUI
import Combine
import ServiceManagement
import UserNotifications

// MARK: - Enums for Settings

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { self.rawValue }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case russian = "Русский"
    case english = "English"
    
    var id: String { self.rawValue }
}

// MARK: - Settings Manager

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @AppStorage("appTheme") var currentTheme: AppTheme = .system
    @AppStorage("appLanguage") var currentLanguage: AppLanguage = .russian
    
    // Automation
    @AppStorage("showNotifications") var showNotifications: Bool = true
    /// Показывать главное окно сразу после запуска приложения.
    @AppStorage("openWindowOnLaunch") var showWindowOnLaunch: Bool = true
    
    // OCR
    /// Глобальная горячая клавиша ⌘⇧Space для захвата области.
    @AppStorage("ocrGlobalHotkey") var ocrGlobalHotkeyEnabled: Bool = true {
        didSet { applyGlobalHotkeyState() }
    }
    /// Автоматически копировать распознанный текст в буфер после захвата.
    @AppStorage("ocrAutoCopyResult") var ocrAutoCopyResult: Bool = false
    
    // Dock Icon Logic
    @AppStorage("hideDockIcon") var hideDockIcon: Bool = false {
        didSet {
            updateDockIconVisibility()
        }
    }
    
    @AppStorage("launchAtLogin") var isLaunchAtLoginEnabled: Bool = false {
        didSet { toggleLaunchAtLogin(enabled: isLaunchAtLoginEnabled) }
    }
    
    init() {
        updateDockIconVisibility()
        requestNotificationAuthorizationIfPossible()
    }
    
    /// Приводит состояние глобального хоткея в соответствие с настройкой.
    func applyGlobalHotkeyState() {
        if ocrGlobalHotkeyEnabled {
            GlobalHotkeyManager.shared.start()
        } else {
            GlobalHotkeyManager.shared.stop()
        }
    }
    
    private func requestNotificationAuthorizationIfPossible() {
        // UNUserNotificationCenter.current() бросает ObjC-исключение, если у
        // процесса нет bundle identifier (запуск "голого" бинарника, превью и т.п.).
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    private func updateDockIconVisibility() {
        DispatchQueue.main.async {
            if self.hideDockIcon {
                NSApp.setActivationPolicy(.accessory)
            } else {
                NSApp.setActivationPolicy(.regular)
            }
        }
    }
    
    private func toggleLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            try? (enabled ? service.register() : service.unregister())
        }
    }
    
    func sendNotification(title: String, body: String) {
        guard showNotifications, Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    func t(_ key: StringKey) -> String {
        return key.localized(lang: currentLanguage)
    }
}
