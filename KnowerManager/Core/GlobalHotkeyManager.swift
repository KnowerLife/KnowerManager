import AppKit
import Carbon.HIToolbox

// MARK: - Глобальная горячая клавиша захвата области (OCR)
//
// Регистрируется через Carbon `RegisterEventHotKey` — работает системно-глобально
// и НЕ требует разрешения Accessibility (в отличие от CGEventTap).
// Комбинация: ⌘⇧Space (см. `keyCode`/`modifiers`).

/// Подпись ('KMNG') и идентификатор нашего хоткея — чтобы отличать его в обработчике.
private let kGlobalHotkeySignature: OSType = 0x4B4D_4E47 // 'KMNG'
private let kGlobalHotkeyID: UInt32 = 1
private let kGlobalHotkeyKeyCode: UInt32 = UInt32(kVK_Space)
private let kGlobalHotkeyModifiers: UInt32 = UInt32(cmdKey | shiftKey)

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
final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var isStarted = false

    private init() {}

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
        RegisterEventHotKey(kGlobalHotkeyKeyCode,
                            kGlobalHotkeyModifiers,
                            hotKeyID,
                            GetEventDispatcherTarget(),
                            0,
                            &hotKeyRef)
    }
}
