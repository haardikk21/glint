import AppKit

enum TerminalCommand: CaseIterable {
    case pi, openCode

    var title: String {
        switch self {
        case .pi: "Pi"
        case .openCode: "OpenCode"
        }
    }

    var command: String {
        switch self {
        case .pi: "pi"
        case .openCode: "oc"
        }
    }
}

enum GhosttyLauncher {
    static func launch(_ choice: TerminalCommand) -> String? {
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.mitchellh.ghostty") != nil else {
            return "Ghostty is not installed."
        }
        guard let script = NSAppleScript(source: script(for: choice)) else {
            return "Could not create the Ghostty command."
        }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        return error?[NSAppleScript.errorMessage] as? String
    }

    static func script(for choice: TerminalCommand) -> String {
        """
        tell application id "com.mitchellh.ghostty"
            set cfg to new surface configuration
            set initial input of cfg to "\(choice.command)" & return
            if (count of windows) > 0 then
                set createdTab to new tab in front window with configuration cfg
                select tab createdTab
            else
                set createdWindow to new window with configuration cfg
                activate window createdWindow
            end if
            activate
        end tell
        """
    }
}
