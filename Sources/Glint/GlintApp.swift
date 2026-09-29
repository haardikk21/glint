import AppKit
import ApplicationServices
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
    private var localKeyMonitor: Any?
    private var previousApplication: NSRunningApplication?
    private var shortcutRetryTimer: Timer?
    private var subscriptions = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let mainMenu = NSMenu()
        let appItem = NSMenuItem(title: "Glint", action: nil, keyEquivalent: "")
        let appMenu = NSMenu(title: "Glint")
        let quitItem = appMenu.addItem(withTitle: "Quit Glint", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu

        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 660, height: 490),
                            styleMask: [.titled, .fullSizeContentView, .closable, .utilityWindow],
                            backing: .buffered, defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            panel.standardWindowButton(button)?.isHidden = true
        }
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.isRestorable = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: LauncherView(model: model))
        panel.delegate = self
        self.panel = panel
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let panel = self.panel, panel.isKeyWindow,
                  event.window == nil || event.window === panel else { return event }
            if self.model.page != .search {
                if let paste = LauncherNavigation.snippetPaste(for: event.keyCode, modifiers: event.modifierFlags) {
                    let action: Notification.Name = self.model.page == .emoji ? .glintEmojiAction :
                        self.model.page == .files ? .glintFileAction : .glintSnippetAction
                    NotificationCenter.default.post(name: action, object: paste)
                    return nil
                }
                if event.keyCode == 53 {
                    NotificationCenter.default.post(name: .glintBack, object: nil)
                    return nil
                }
            }
            if self.model.page == .emoji,
               let direction = LauncherNavigation.gridDirection(for: event.keyCode, modifiers: event.modifierFlags) {
                NotificationCenter.default.post(name: .glintEmojiNavigate, object: direction)
                return nil
            }
            if let direction = LauncherNavigation.direction(for: event.keyCode, modifiers: event.modifierFlags) {
                NotificationCenter.default.post(name: .glintNavigate, object: direction)
                return nil
            }
            return event
        }

        model.hide = { [weak self] in self?.panel?.orderOut(nil) }
        model.openSettings = { [weak self] in self?.showSettings() }
        model.openSnippetSettings = { [weak self] in self?.presentSettings(tab: 2) }
        model.pasteIntoPreviousApp = { [weak self] in self?.pasteIntoPreviousApp() }
        previousApplication = NSWorkspace.shared.frontmostApplication
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .compactMap { $0.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication }
            .sink { [weak self] application in
                Task { @MainActor in
                    if application.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                        self?.previousApplication = application
                    }
                }
            }.store(in: &subscriptions)

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
        shortcutRetryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let hotkeys = self.hotkeys, !hotkeys.launcherAvailable else { return }
                if hotkeys.retryLauncher(toggle: { [weak self] in self?.toggle() }),
                   self.model.message?.hasPrefix("Launcher: shortcut unavailable") == true {
                    self.model.message = hotkeys.failures.isEmpty ? nil : hotkeys.failures.joined(separator: ", ")
                }
            }
        }
    }

    @objc private func toggle() {
        guard let panel else { return }
        if panel.isVisible { panel.orderOut(nil) }
        else {
            if let front = NSWorkspace.shared.frontmostApplication,
               front.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                previousApplication = front
            }
            model.reset()
            panel.center()
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func showSettings() {
        presentSettings(tab: 0)
    }

    private func presentSettings(tab: Int) {
        model.settingsTab = tab
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

    private func pasteIntoPreviousApp() {
        guard let target = previousApplication, !target.isTerminated,
              target.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            model.message = "Copied. Open the target app and press ⌘V to paste."
            return
        }
        guard AXIsProcessTrusted() else {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            model.message = "Copied. Allow Glint in Accessibility settings, then try ⇧↵ again."
            return
        }
        guard target.activate() else {
            model.message = "Copied. Could not activate the target app."
            return
        }
        Task { @MainActor [weak self] in
            for _ in 0..<10 {
                if NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier {
                    guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true),
                          let up = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false) else {
                        self?.model.message = "Copied. Could not send paste to the target app."
                        return
                    }
                    down.flags = .maskCommand
                    up.flags = .maskCommand
                    down.post(tap: .cghidEventTap)
                    up.post(tap: .cghidEventTap)
                    return
                }
                try? await Task.sleep(nanoseconds: 60_000_000)
            }
            self?.model.message = "Copied. Could not focus the target app to paste."
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let localKeyMonitor { NSEvent.removeMonitor(localKeyMonitor) }
        shortcutRetryTimer?.invalidate()
    }

    func windowDidResignKey(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === panel { panel?.orderOut(nil) }
    }

    func applicationShouldSaveApplicationState(_ sender: NSApplication) -> Bool { false }
    func applicationShouldRestoreApplicationState(_ sender: NSApplication) -> Bool { false }
    func applicationShouldSaveSecureApplicationState(_ sender: NSApplication) -> Bool { false }
    func applicationShouldRestoreSecureApplicationState(_ sender: NSApplication) -> Bool { false }
}
