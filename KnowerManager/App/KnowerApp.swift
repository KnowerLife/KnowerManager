import SwiftUI

@main
struct KnowerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        let settingsManager = SettingsManager.shared
        MenuBarManager.shared.setup(settings: settingsManager)
        settingsManager.applyGlobalHotkeyState()
        if settingsManager.showWindowOnLaunch {
            MenuBarManager.shared.openMainWindow()
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            MenuBarManager.shared.openMainWindow()
        }
        return true
    }
}
