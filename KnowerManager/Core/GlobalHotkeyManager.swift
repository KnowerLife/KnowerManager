import AppKit
import Carbon.HIToolbox
import Combine

// MARK: - Глобальная горячая клавиша захвата области (OCR)
//
// Регистрируется через Carbon `RegisterEventHotKey` — работает системно-глобально
// и НЕ требует разрешения Accessibility (в отличие от CGEventTap).
// Комбинация по умолчанию: ⌘⇧Space. Пользовательская комбинация сохраняется
// в UserDefaults.

/// Подпись ('KMNG') и идентификатор нашего хоткея — чтобы отличать его в обработчике.
private let kGlobalHotkeySignature: OSType = 0x4B4D_4E47 // 'KMNG'
private let kGlobalHotkeyID: UInt32 = 1

/// C-совместимый обработчик события хоткея. Обязательно `nonisolated`,
/// т.к. вызывается из C и не должен попадать на MainActor по умолчанию.
private nonisolated func globalHotKeyHandler(_ nextHandler: EventHandlerCallRef?,
                                             _ event: EventRef?,
                                             _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event = event else { return noErr }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(event,
                                   EventParamName(kEventParamDirectObject),
                                   EventParamType(typeEventHotKeyID),
                                   nil,
                                   MemoryLayout<EventHotKeyID>.size,
                                   nil,
                                   &hotKeyID)
    guard status == noErr else { return noErr }
    // Подпись 'KMNG' и id 1 — те же значения, что в GlobalHotkeyManager.
    // Литералы, т.к. глобальные let изолированы на MainActor по умолчанию.
    guard hotKeyID.signature == 0x4B4D_4E47,
          hotKeyID.id == 1 else { return noErr }

    // Хоткей приходит на главном потоке, но переносим в явный MainActor-контекст,
    // чтобы безопасно работать с UI и OCRManager.
    Task { @MainActor in
        NSApp.activate(ignoringOtherApps: true)
        OCRManager.shared.captureArea()
    }
    return noErr
}

/// Регистрирует/снимает глобальный хоткей захвата области для OCR.
final class GlobalHotkeyManager: ObservableObject {
    static let shared = GlobalHotkeyManager()

    /// Значение по умолчанию — ⌘⇧Space.
    static let defaultKeyCode = UInt32(kVK_Space)
    static let defaultModifiers = UInt32(cmdKey | shiftKey)

    private enum DefaultsKey {
        static let keyCode = "ocrHotkeyKeyCode"
        static let modifiers = "ocrHotkeyModifiers"
    }

    /// Текущий код клавиши.
    @Published private(set) var keyCode: UInt32
    /// Текущие модификаторы (Carbon-константы).
    @Published private(set) var modifiers: UInt32

    /// Идёт ли запись новой комбинации.
    @Published private(set) var isRecording = false

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var isStarted = false

    /// Локальный монитор для записи новой комбинации (не требует разрешений,
    /// т.к. окно настроек становится key-окном во время записи).
    private var recordMonitor: Any?

    private init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: DefaultsKey.keyCode) != nil {
            keyCode = UInt32(defaults.integer(forKey: DefaultsKey.keyCode))
            modifiers = UInt32(defaults.integer(forKey: DefaultsKey.modifiers))
        } else {
            keyCode = Self.defaultKeyCode
            modifiers = Self.defaultModifiers
        }
    }

    // MARK: - Public API

    /// Включает глобальный хоткей (идемпотентно).
    func start() {
        guard !isStarted else { return }
        isStarted = true
        installHandlerIfNeeded()
        registerHotKey()
    }

    /// Выключает глобальный хоткей и снимает обработчик.
    func stop() {
        guard isStarted else { return }
        isStarted = false
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }

    /// Обновляет комбинацию клавиш, сохраняет её и перерегистрирует хоткей.
    func updateHotkey(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers

        let defaults = UserDefaults.standard
        defaults.set(Int(keyCode), forKey: DefaultsKey.keyCode)
        defaults.set(Int(modifiers), forKey: DefaultsKey.modifiers)

        if isStarted {
            if let ref = hotKeyRef {
                UnregisterEventHotKey(ref)
                hotKeyRef = nil
            }
            registerHotKey()
        }
    }

    /// Сбрасывает комбинацию к значению по умолчанию (⌘⇧Space).
    func resetToDefault() {
        updateHotkey(keyCode: Self.defaultKeyCode, modifiers: Self.defaultModifiers)
    }

    /// Начинает запись новой комбинации клавиш.
    @discardableResult
    func startRecording() -> Bool {
        guard recordMonitor == nil else { return true }
        isRecording = true
        recordMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return event }
            // Игнорируем сами модификаторы (⌘, ⇧, ⌥, ⌃, CapsLock, Fn).
            let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
            if modifierKeyCodes.contains(event.keyCode) { return nil }

            let newModifiers = self.carbonModifiers(from: event.modifierFlags)
            // Требуем хотя бы один модификатор, иначе случайное нажатие
            // клавиши перехватит всю клавиатуру.
            guard newModifiers != 0 else { return nil }

            self.updateHotkey(keyCode: UInt32(event.keyCode), modifiers: newModifiers)
            self.stopRecording()
            return nil // Событие поглощено.
        }
        return recordMonitor != nil
    }

    /// Останавливает запись комбинации.
    func stopRecording() {
        if let monitor = recordMonitor {
            NSEvent.removeMonitor(monitor)
            recordMonitor = nil
        }
        isRecording = false
    }

    /// Возвращает строковое представление текущей комбинации, например «⌘⇧Space».
    var combinationString: String {
        Self.combinationString(keyCode: keyCode, modifiers: modifiers)
    }

    /// Строковое представление произвольной комбинации.
    static func combinationString(keyCode: UInt32, modifiers: UInt32) -> String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(keyCodeToString(keyCode))
        return parts.joined()
    }

    // MARK: - Private

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        return result
    }

    private static func keyCodeToString(_ keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return, kVK_ANSI_KeypadEnter: return "↩"
        case kVK_Escape: return "Esc"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_Tab: return "⇥"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_Home: return "↖"
        case kVK_End: return "↘"
        case kVK_PageUp: return "⇞"
        case kVK_PageDown: return "⇟"
        default:
            if let keyChar = keyCodeMap[Int(keyCode)] { return keyChar }
            return "Key\(keyCode)"
        }
    }

    private static let keyCodeMap: [Int: String] = [
        kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C",
        kVK_ANSI_D: "D", kVK_ANSI_E: "E", kVK_ANSI_F: "F",
        kVK_ANSI_G: "G", kVK_ANSI_H: "H", kVK_ANSI_I: "I",
        kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
        kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O",
        kVK_ANSI_P: "P", kVK_ANSI_Q: "Q", kVK_ANSI_R: "R",
        kVK_ANSI_S: "S", kVK_ANSI_T: "T", kVK_ANSI_U: "U",
        kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
        kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
        kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2",
        kVK_ANSI_3: "3", kVK_ANSI_4: "4", kVK_ANSI_5: "5",
        kVK_ANSI_6: "6", kVK_ANSI_7: "7", kVK_ANSI_8: "8",
        kVK_ANSI_9: "9",
        kVK_ANSI_Minus: "-", kVK_ANSI_Equal: "=",
        kVK_ANSI_LeftBracket: "[", kVK_ANSI_RightBracket: "]",
        kVK_ANSI_Backslash: "\\", kVK_ANSI_Semicolon: ";",
        kVK_ANSI_Quote: "'", kVK_ANSI_Comma: ",",
        kVK_ANSI_Period: ".", kVK_ANSI_Slash: "/",
        kVK_ANSI_Grave: "`"
    ]

    private func installHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(),
                            globalHotKeyHandler,
                            1,
                            &eventType,
                            nil,
                            &eventHandlerRef)
    }

    private func registerHotKey() {
        let hotKeyID = EventHotKeyID(signature: kGlobalHotkeySignature, id: kGlobalHotkeyID)
        RegisterEventHotKey(keyCode,
                            modifiers,
                            hotKeyID,
                            GetEventDispatcherTarget(),
                            0,
                            &hotKeyRef)
    }
}
