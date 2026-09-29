import AppKit
import Carbon
import SwiftUI

@MainActor final class HotkeyManager {
    private var registrations: [EventHotKeyRef] = []
    private var actions: [UInt32: () -> Void] = [:]
    private var handler: EventHandlerRef?
    private(set) var failures: [String] = []
    var launcherAvailable: Bool { actions[1] != nil }

    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return noErr }
            var identifier = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            if status == noErr {
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in manager.actions[identifier.id]?() }
            }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    func configure(scripts: [ScriptCommand], toggle: @escaping () -> Void, run: @escaping (ScriptCommand) -> Void) {
        for registration in registrations { UnregisterEventHotKey(registration) }
        registrations.removeAll()
        actions.removeAll()
        failures.removeAll()
        register(key: 49, modifiers: UInt32(cmdKey), id: 1, label: "Launcher", action: toggle)
        for (index, script) in scripts.enumerated() {
            guard let key = script.keyCode, let modifiers = script.modifiers else { continue }
            register(key: key, modifiers: modifiers, id: UInt32(index + 2), label: script.name) {
                run(script)
            }
        }
    }

    func retryLauncher(toggle: @escaping () -> Void) -> Bool {
        guard !launcherAvailable else { return true }
        failures.removeAll { $0.hasPrefix("Launcher: ") }
        register(key: 49, modifiers: UInt32(cmdKey), id: 1, label: "Launcher", action: toggle)
        return launcherAvailable
    }

    private func register(key: UInt32, modifiers: UInt32, id: UInt32, label: String, action: @escaping () -> Void) {
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(key, modifiers, EventHotKeyID(signature: 0x474C4E54, id: id),
                                         GetApplicationEventTarget(), 0, &reference)
        if status == noErr, let reference {
            registrations.append(reference)
            actions[id] = action
        } else { failures.append("\(label): shortcut unavailable (\(status))") }
    }

    deinit {
        for registration in registrations { UnregisterEventHotKey(registration) }
        if let handler { RemoveEventHandler(handler) }
    }
}

struct ShortcutRecorder: NSViewRepresentable {
    let onRecord: (UInt32, UInt32, String) -> Void

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.onRecord = onRecord
        return view
    }

    func updateNSView(_ view: RecorderView, context: Context) { view.onRecord = onRecord }

    final class RecorderView: NSButton {
        var onRecord: ((UInt32, UInt32, String) -> Void)?

        override init(frame: NSRect) {
            super.init(frame: frame)
            title = "Click, then press a shortcut"
            bezelStyle = .rounded
            target = self
            action = #selector(focus)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
        override var acceptsFirstResponder: Bool { true }

        @objc private func focus() {
            window?.makeFirstResponder(self)
            title = "Press shortcut…"
        }

        override func keyDown(with event: NSEvent) {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            var modifiers: UInt32 = 0
            if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
            if flags.contains(.option) { modifiers |= UInt32(optionKey) }
            if flags.contains(.control) { modifiers |= UInt32(controlKey) }
            if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
            guard modifiers != 0 else { NSSound.beep(); return }
            let label = [flags.contains(.control) ? "⌃" : "", flags.contains(.option) ? "⌥" : "",
                         flags.contains(.shift) ? "⇧" : "", flags.contains(.command) ? "⌘" : "",
                         event.charactersIgnoringModifiers?.uppercased() ?? ""].joined()
            title = label
            onRecord?(UInt32(event.keyCode), modifiers, label)
            window?.makeFirstResponder(nil)
        }
    }
}
