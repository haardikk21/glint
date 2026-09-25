import AppKit

enum SystemActions {
    static let appearanceScript = "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode"

    static func toggleAppearance() -> String? {
        guard let script = NSAppleScript(source: appearanceScript) else {
            return "Could not create the appearance command."
        }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        return error?[NSAppleScript.errorMessage] as? String
    }
}
