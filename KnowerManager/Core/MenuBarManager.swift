import Cocoa
import SwiftUI
import Combine

// MARK: - Event Monitor
class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void

    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }

    deinit { stop() }

    func start() {
        // Если монитор уже запущен, не запускаем второй
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }

    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

// MARK: - Focus Aware Controller
class FocusAwareHostingController<Content: View>: NSHostingController<Content> {
    override var acceptsFirstResponder: Bool { true }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        NSApp.activate(ignoringOtherApps: true)
        self.view.window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - MenuBarManager
class MenuBarManager: NSObject, NSPopoverDelegate, NSWindowDelegate {
    static let shared = MenuBarManager()
    
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: EventMonitor?
    
    var knowerManager: KnowerManager?
    var settingsManager: SettingsManager?
    
    // Храним ссылки на окна явно
    private var mainWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var settingsWindow: NSWindow?
    
    private var cancellables = Set<AnyCancellable>()
    
    func setup(knower: KnowerManager, settings: SettingsManager) {
        self.knowerManager = knower
        self.settingsManager = settings
        
        // 1. Status Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Используем системную иконку или свою из Assets
            button.image = NSImage(systemSymbolName: "shield", accessibilityDescription: "Knower Manager")
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // 2. Popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 560)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = FocusAwareHostingController(rootView: MiniMenu())
        
        // 3. Event Monitor с защитой от конфликтов
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return }
            
            if self.popover.isShown {
                // ВАЖНО: Если клик был по самой кнопке в меню-баре, игнорируем его тут.
                // Кнопка сама вызовет togglePopover. Иначе меню закроется и тут же откроется снова.
                if let button = self.statusItem.button,
                   let window = button.window {
                    
                    // Если это глобальное событие, координаты могут быть экранными
                    // Простая проверка: если мышь над кнопкой меню, не закрываем через монитор
                    let mouseLocation = NSEvent.mouseLocation
                    if NSPointInRect(mouseLocation, window.frame) {
                        return
                    }
                }
                
                self.closePopover(sender: event)
            }
        }
        
        // 4. Подписки
        knower.$isRunning
            .receive(on: RunLoop.main)
            .sink { [weak self] isRunning in self?.updateIconState(isRunning: isRunning) }
            .store(in: &cancellables)
        
        updateIconState(isRunning: knower.isRunning)
    }
    
    // MARK: - Popover Logic
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover(sender: sender)
        } else {
            showPopover(sender: sender)
        }
    }
    
    private func showPopover(sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        
        eventMonitor?.start()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // Форсируем обновление UI
        popover.contentViewController?.view.needsLayout = true
    }
    
    private func closePopover(sender: AnyObject?) {
        popover.close()
        eventMonitor?.stop()
    }
    
    func popoverDidClose(_ notification: Notification) {
        eventMonitor?.stop()
    }
    
    // MARK: - Window Management (FIXED)
    
    @objc func toggleService() {
        knowerManager?.toggleService()
    }
    
    @objc func openSettings() {
        closePopover(sender: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate(ignoringOtherApps: true)
            
            if self.settingsWindow == nil {
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 420, height: 700),
                    styleMask: [.titled, .closable, .miniaturizable],
                    backing: .buffered, defer: false)
                
                window.center()
                window.title = SettingsManager.shared.t(.settingsTitle)
                window.isReleasedWhenClosed = false // Мы сами управляем жизнью окна
                window.delegate = self // Чтобы обнулить переменную при закрытии
                window.contentView = NSHostingView(rootView: GeneralSettingsSheet())
                self.settingsWindow = window
            }
            
            self.settingsWindow?.makeKeyAndOrderFront(nil)
            self.settingsWindow?.center()
        }
    }
    
    // ГЛАВНОЕ ОКНО: Полное ручное управление
    func openMainWindow(tab: Int = 0) {
            closePopover(sender: nil)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.activate(ignoringOtherApps: true)
                
                // Если окна нет или оно было закрыто (released)
                if self.mainWindow == nil {
                    let window = NSWindow(
                        contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
                        // ДОБАВЛЕНО: .fullSizeContentView позволяет контенту залазить под заголовок
                        styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                        backing: .buffered, defer: false)
                    
                    window.title = "Knower Manager"
                    window.center()
                    window.isReleasedWhenClosed = false
                    window.delegate = self
                    
                    // --- НАСТРОЙКИ ВНЕШНЕГО ВИДА (СКРЫВАЕМ ЗАГОЛОВОК) ---
                    window.titlebarAppearsTransparent = true // Прозрачный бар
                    window.titleVisibility = .hidden         // Скрываем текст "Knower Manager"
                    
                    // Если хотите сделать окно перетаскиваемым за фон (как в SwiftUI):
                    window.isMovableByWindowBackground = true
                    
                    // Если нужно скрыть стандартные кнопки светофора (крестик и т.д.), раскомментируйте:
                    // window.standardWindowButton(.closeButton)?.isHidden = true
                    // window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                    // window.standardWindowButton(.zoomButton)?.isHidden = true
                    // -----------------------------------------------------
                    
                    let rootView = ContentView()
                    
                    window.contentView = NSHostingView(rootView: rootView)
                    self.mainWindow = window
                }
                
                self.mainWindow?.makeKeyAndOrderFront(nil)
                
                // Уведомление для смены таба
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NotificationCenter.default.post(name: NSNotification.Name("SwitchTab"), object: nil, userInfo: ["tab": tab])
                }
            }
        }
    
    @objc func openAbout() {
        closePopover(sender: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate(ignoringOtherApps: true)
            
            if self.aboutWindow == nil {
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 460, height: 700),
                    styleMask: [.titled, .closable, .fullSizeContentView],
                    backing: .buffered, defer: false)
                window.center()
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.isReleasedWhenClosed = false
                window.isMovableByWindowBackground = true
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                window.standardWindowButton(.zoomButton)?.isHidden = true
                window.contentView = NSHostingView(rootView: AboutView())
                self.aboutWindow = window
            }
            self.aboutWindow?.makeKeyAndOrderFront(nil)
            self.aboutWindow?.center()
        }
    }
    
    @objc func quitApp() {
        if let manager = knowerManager, manager.isRunning {
            manager.toggleService()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { NSApp.terminate(nil) }
        } else {
            NSApp.terminate(nil)
        }
    }
    
    // MARK: - NSWindowDelegate
    // Этот метод вызывается, когда пользователь нажимает "крестик"
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        
        if window == mainWindow {
            // Не обнуляем mainWindow, просто скрываем (isReleasedWhenClosed = false).
            // Это позволяет сохранить состояние окна (например, выбранный таб).
            // Если вы хотите полный сброс при закрытии, раскомментируйте:
            // mainWindow = nil
        } else if window == settingsWindow {
            settingsWindow = nil
        } else if window == aboutWindow {
            aboutWindow = nil
        }
    }
    
    // MARK: - Icon Logic
    
    private func updateIconState(isRunning: Bool) {
        guard let button = statusItem.button else { return }
        button.contentTintColor = nil
        
        if isRunning {
            let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .heavy)
                .applying(.init(hierarchicalColor: .systemGreen))
            
            if let icon = NSImage(systemSymbolName: "shield.fill", accessibilityDescription: "Active") {
                let coloredIcon = icon.withSymbolConfiguration(config)
                coloredIcon?.isTemplate = false
                button.image = coloredIcon
            }
        } else {
            let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .heavy)
            if let icon = NSImage(systemSymbolName: "shield", accessibilityDescription: "Inactive") {
                let boldIcon = icon.withSymbolConfiguration(config)
                boldIcon?.isTemplate = true
                button.image = boldIcon
            }
        }
    }
}
