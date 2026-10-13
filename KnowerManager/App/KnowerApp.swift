import SwiftUI

@main
struct KnowerApp: App {
    // Подключаем AppDelegate.
    // Именно он теперь будет инициализировать UI через MenuBarManager.
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // ВАЖНО: Мы убрали WindowGroup { ContentView(...) }.
        // Теперь главным окном управляет MenuBarManager вручную.
        // Это решает проблему "не открывается после закрытия".
        
        // SwiftUI требует вернуть хотя бы одну сцену.
        // Settings { EmptyView() } — это стандартный способ сказать SwiftUI:
        // "Не создавай никаких окон автоматически, я сделаю это сам".
        Settings {
            EmptyView()
        }
        .commands {
            // Убираем лишние пункты меню (File -> New и т.д.)
            CommandGroup(replacing: .newItem) {}
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Отключаем назойливые системные вкладки macOS
        NSWindow.allowsAutomaticWindowTabbing = false
        
        // 1. Получаем ссылки на синглтоны
        let settingsManager = SettingsManager.shared
        
        // 2. Настраиваем Трей (MenuBarManager)
        // Он инициализирует MiniMenu и монитор событий
        MenuBarManager.shared.setup(settings: settingsManager)
        
        // 3. ЯВНО открываем главное окно при старте приложения
        // Так как WindowGroup убрана, без этого вызова приложение запустится без окна
        MenuBarManager.shared.openMainWindow()
    }
    
    // Приложение НЕ закрывается полностью, когда закрыто окно (остается в трее)
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    // Обработка клика по иконке в Доке: восстановить окно через наш менеджер
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Если видимых окон нет, просим MenuBarManager открыть главное
        if !flag {
            MenuBarManager.shared.openMainWindow()
        }
        return true
    }
}
