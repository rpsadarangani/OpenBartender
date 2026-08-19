import AppKit
import Carbon.HIToolbox

/// Registers a single system-wide hotkey via Carbon's `RegisterEventHotKey`.
///
/// Carbon hotkeys are the standard way to get a global shortcut WITHOUT the
/// Accessibility / Input Monitoring permission that `NSEvent` global monitors
/// require — keeping OpenBartender permission-free.
final class HotKeyManager {
    static let shared = HotKeyManager()

    /// Called on the main thread whenever the hotkey fires.
    var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let signature: OSType = 0x4F42_4152 // 'OBAR'

    private init() {
        installHandler()
    }

    private func installHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: OSType(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ -> OSStatus in
            HotKeyManager.shared.onTrigger?()
            return noErr
        }, 1, &spec, nil, &eventHandler)
    }

    /// (Re)register the hotkey. Pass `enabled: false` to clear it.
    func update(enabled: Bool, keyCode: UInt32, carbonModifiers: UInt32) {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        guard enabled, keyCode != 0 else { return }

        let id = EventHotKeyID(signature: signature, id: 1)
        RegisterEventHotKey(keyCode, carbonModifiers, id,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}
