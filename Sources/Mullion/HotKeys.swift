#if os(macOS)
import Carbon
import MullionCore

/// Global hotkeys via Carbon's RegisterEventHotKey. Unlike an event tap, this needs no Input Monitoring
/// permission and never sees keystrokes other than the registered ones.
@MainActor
final class HotKeys {
    private var refs: [EventHotKeyRef] = []
    private var handlers: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var hotKeyID = EventHotKeyID()
                let err = GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
                guard err == noErr else { return err }
                let hotKeys = Unmanaged<HotKeys>.fromOpaque(userData).takeUnretainedValue()
                let id = hotKeyID.id
                // Carbon delivers hotkey events on the main run loop.
                MainActor.assumeIsolated { hotKeys.fire(id) }
                return noErr
            },
            1, &spec, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
        if status != noErr { Log.error("could not install hotkey handler (OSStatus \(status))") }
    }

    /// Returns false if the combo could not be registered, usually because another app already owns it.
    /// macOS only refuses a combo when both apps ask for it exclusively; any other overlap succeeds silently.
    func register(_ combo: KeyCombo, handler: @escaping () -> Void) -> Bool {
        let id = EventHotKeyID(signature: OSType(0x4D4C_4C4E) /* 'MLLN' */, id: nextID)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(combo.keyCode, combo.modifiers, id, GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &ref)
        guard status == noErr, let ref else { return false }
        refs.append(ref)
        handlers[nextID] = handler
        nextID += 1
        return true
    }

    func unregisterAll() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
        handlers.removeAll()
    }

    private func fire(_ id: UInt32) {
        handlers[id]?()
    }
}
#endif
