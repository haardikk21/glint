import AppKit
import Combine
import SwiftUI

@main struct GlintApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let model = LauncherModel()
    private var panel: NSPanel?
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var hotkeys: HotkeyManager?
    private var subscriptions = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 660, height: 490),
                            styleMask: [.titled, .fullSizeContentView, .closable, .utilityWindow],
                            backing: .buffered, defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.isRestorable = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: LauncherView(model: model))
        panel.delegate = self
        self.panel = panel

        model.hide = { [weak self] in self?.panel?.orderOut(nil) }
        model.openSettings = { [weak self] in self?.showSettings() }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "sparkle.magnifyingglass", accessibilityDescription: "Glint")
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Glint", action: #selector(toggle), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Glint", action: #selector(quit), keyEquivalent: "")
        for entry in menu.items { entry.target = self }
        item.menu = menu
        statusItem = item

        let hotkeys = HotkeyManager()
        self.hotkeys = hotkeys
        model.preferences.$scripts.sink { [weak self] scripts in
            Task { @MainActor [weak self] in
                guard let self else { return }
                hotkeys.configure(scripts: scripts, toggle: { [weak self] in self?.toggle() },
                                  run: { [weak self] script in self?.model.run(script) })
                if !hotkeys.failures.isEmpty { self.model.message = hotkeys.failures.joined(separator: ", ") }
            }
        }.store(in: &subscriptions)
    }

    @objc private func toggle() {
        guard let panel else { return }
        if panel.isVisible { panel.orderOut(nil) }
        else {
            model.reset()
            panel.center()
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 520),
                                  styleMask: [.titled, .closable, .miniaturizable],
                                  backing: .buffered, defer: false)
            window.title = "Glint Settings"
            window.isReleasedWhenClosed = false
            window.isRestorable = false
            window.contentView = NSHostingView(rootView: SettingsView(model: model))
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() { NSApp.terminate(nil) }

    func windowDidResignKey(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === panel { panel?.orderOut(nil) }
    }

    func applicationShouldSaveApplicationState(_ sender: NSApplication) -> Bool { false }
    func applicationShouldRestoreApplicationState(_ sender: NSApplication) -> Bool { false }
    func applicationShouldSaveSecureApplicationState(_ sender: NSApplication) -> Bool { false }
    func applicationShouldRestoreSecureApplicationState(_ sender: NSApplication) -> Bool { false }
}
