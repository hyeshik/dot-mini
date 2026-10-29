import Carbon
import Combine
import Foundation
import YourDotMiniCore

@MainActor
final class GlobalHotKeyService: ObservableObject {
    @Published private(set) var message = "Shortcut is off."
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var current: GlobalShortcut?
    private var currentID: UInt32 = 0
    var onPressed: (() -> Void)?

    func apply(_ shortcut: GlobalShortcut?) -> Bool {
        guard shortcut != current else { message = shortcut.map { "\($0.label) opens or hides your dot." } ?? "Shortcut is off."; return true }
        guard let shortcut else { stopKey(); message = "Shortcut is off."; return true }
        guard shortcut.isValid else { message = "Choose a supported key with Control or Command."; return false }
        if handler == nil {
            var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
                guard let event, let context else { return OSStatus(eventNotHandledErr) }
                var identifier = EventHotKeyID()
                let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                              nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
                guard status == noErr else { return status }
                return MainActor.assumeIsolated {
                    let service = Unmanaged<GlobalHotKeyService>.fromOpaque(context).takeUnretainedValue()
                    guard service.hotKey != nil, identifier.signature == 0x59444D4E,
                          identifier.id == service.currentID else { return OSStatus(eventNotHandledErr) }
                    service.onPressed?()
                    return noErr
                }
            }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
            guard status == noErr else { message = "Shortcut event registration failed (\(status)). Menu bar access still works."; return false }
        }
        var modifiers: UInt32 = 0
        if shortcut.modifiers & GlobalShortcut.control != 0 { modifiers |= UInt32(controlKey) }
        if shortcut.modifiers & GlobalShortcut.option != 0 { modifiers |= UInt32(optionKey) }
        if shortcut.modifiers & GlobalShortcut.shift != 0 { modifiers |= UInt32(shiftKey) }
        if shortcut.modifiers & GlobalShortcut.command != 0 { modifiers |= UInt32(cmdKey) }
        var symbolicKeys: Unmanaged<CFArray>?
        let lookup = CopySymbolicHotKeys(&symbolicKeys)
        guard lookup == noErr, let symbolicKeys else {
            message = "Could not check macOS shortcuts (\(lookup)). Try again; the previous shortcut is unchanged."
            return false
        }
        let reserved = symbolicKeys.takeRetainedValue() as NSArray
        if reserved.contains(where: { value in
            guard let entry = value as? NSDictionary else { return false }
            return (entry[kHISymbolicHotKeyEnabled] as? NSNumber)?.boolValue == true &&
                (entry[kHISymbolicHotKeyCode] as? NSNumber)?.uint32Value == shortcut.keyCode &&
                (entry[kHISymbolicHotKeyModifiers] as? NSNumber)?.uint32Value == modifiers
        }) {
            message = "macOS uses that shortcut. Choose another; the previous shortcut is unchanged."
            return false
        }
        let nextID = currentID &+ 1
        var candidate: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: 0x59444D4E, id: nextID)
        // A normal registration can silently coexist with an exclusive owner
        // without receiving events. Probe for such an owner before replacing
        // the current binding. Keep the actual registration nonexclusive: on
        // current macOS an exclusive registration can preempt other apps'
        // nonexclusive subscriptions instead of reporting a conflict.
        var probe: EventHotKeyRef?
        let availability = RegisterEventHotKey(shortcut.keyCode, modifiers, identifier,
            GetApplicationEventTarget(), UInt32(kEventHotKeyExclusive), &probe)
        if let probe { UnregisterEventHotKey(probe) }
        guard availability == noErr, probe != nil else {
            message = "That shortcut is unavailable (\(availability)). Choose another; the previous shortcut is unchanged."
            return false
        }
        let status = RegisterEventHotKey(shortcut.keyCode, modifiers, identifier,
                                         GetApplicationEventTarget(), 0, &candidate)
        guard status == noErr, let candidate else {
            message = "That shortcut is unavailable (\(status)). Choose another; the previous shortcut is unchanged."
            return false
        }
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = candidate
        currentID = nextID
        current = shortcut
        message = "\(shortcut.label) opens or hides your dot."
        return true
    }

    private func stopKey() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
        current = nil
    }
    func stop() {
        stopKey()
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }
}
