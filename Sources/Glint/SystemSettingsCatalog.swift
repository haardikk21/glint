import Foundation

struct SettingsPane: Identifiable {
    let title: String
    let aliases: [String]
    let symbol: String
    let id: String
    let url: URL

    func relevance(for input: String) -> Int? {
        let query = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return nil }
        let name = title.lowercased()
        if name == query { return 900 }
        if name.hasPrefix(query) {
            return (Fuzzy.score(title, for: query) ?? 0) + 50 - max(0, title.count - query.count)
        }
        guard query.count >= 3 else { return nil }
        if aliases.contains(where: { $0.lowercased() == query }) { return 120 }
        if aliases.contains(where: { $0.lowercased().hasPrefix(query) }) { return 90 }

        let words = ([title] + aliases + ["settings"]).joined(separator: " ")
            .lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        let terms = query.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        guard terms.count > 1,
              terms.allSatisfy({ term in words.contains(where: { $0.hasPrefix(term) }) }) else { return nil }
        return 70
    }
}

enum SystemSettingsCatalog {
    private struct Descriptor {
        let title: String
        let extensionName: String
        let aliases: [String]
        let symbol: String
    }

    static let panes: [SettingsPane] = {
        let descriptions: [Descriptor] = [
            .init(title: "Accessibility", extensionName: "AccessibilitySettingsExtension",
                  aliases: ["accessibility settings", "voiceover", "zoom"], symbol: "accessibility"),
            .init(title: "Privacy & Security", extensionName: "SecurityPrivacyExtension",
                  aliases: ["privacy", "security", "permissions"], symbol: "hand.raised"),
            .init(title: "Storage", extensionName: "Storage",
                  aliases: ["disk space", "storage settings"], symbol: "internaldrive"),
            .init(title: "Displays", extensionName: "DisplaysExt",
                  aliases: ["display", "monitor", "screen settings", "brightness"], symbol: "display"),
            .init(title: "Mouse", extensionName: "MouseExtension",
                  aliases: ["mouse settings", "scrolling"], symbol: "computermouse"),
            .init(title: "Keyboard", extensionName: "KeyboardSettings",
                  aliases: ["keyboard settings", "shortcuts", "input sources"], symbol: "keyboard"),
            .init(title: "Trackpad", extensionName: "TrackpadExtension",
                  aliases: ["gestures", "trackpad settings"], symbol: "hand.draw"),
            .init(title: "Appearance", extensionName: "Appearance",
                  aliases: ["theme", "light mode", "dark mode", "colors"], symbol: "circle.lefthalf.filled"),
            .init(title: "Sound", extensionName: "Sound",
                  aliases: ["audio", "volume", "speakers", "microphone"], symbol: "speaker.wave.2"),
            .init(title: "Notifications", extensionName: "NotificationsSettings",
                  aliases: ["alerts", "notification settings"], symbol: "bell"),
            .init(title: "Bluetooth", extensionName: "Bluetooth",
                  aliases: ["bluetooth settings", "wireless devices"], symbol: "antenna.radiowaves.left.and.right"),
            .init(title: "Network", extensionName: "Network",
                  aliases: ["network settings", "ethernet"], symbol: "network"),
            .init(title: "Wi-Fi", extensionName: "Wi-Fi",
                  aliases: ["wifi", "wireless network"], symbol: "wifi"),
            .init(title: "Battery", extensionName: "PowerPreferences",
                  aliases: ["power", "energy", "battery settings"], symbol: "battery.100percent"),
            .init(title: "Login Items", extensionName: "LoginItems",
                  aliases: ["startup apps", "launch at login"], symbol: "person.crop.circle.badge.checkmark"),
            .init(title: "Focus", extensionName: "FocusSettingsExtension",
                  aliases: ["do not disturb", "focus mode"], symbol: "moon"),
            .init(title: "Screen Time", extensionName: "ScreenTimePreferencesExtension",
                  aliases: ["app limits", "parental controls"], symbol: "hourglass"),
            .init(title: "Users & Groups", extensionName: "UsersGroups",
                  aliases: ["users", "accounts", "user groups"], symbol: "person.2"),
            .init(title: "Wallpaper", extensionName: "Wallpaper",
                  aliases: ["desktop picture", "background"], symbol: "photo"),
            .init(title: "Desktop & Dock", extensionName: "DesktopSettings",
                  aliases: ["dock", "desktop settings", "stage manager"], symbol: "dock.rectangle"),
            .init(title: "Control Center", extensionName: "ControlCenterSettings",
                  aliases: ["menu bar", "control centre"], symbol: "switch.2"),
            .init(title: "Siri", extensionName: "SiriPreferenceExtension",
                  aliases: ["voice assistant", "siri settings"], symbol: "waveform"),
            .init(title: "Spotlight", extensionName: "SpotlightPreferenceExtension",
                  aliases: ["search settings", "spotlight settings"], symbol: "magnifyingglass"),
            .init(title: "Software Update", extensionName: "SoftwareUpdateSettingsExtension",
                  aliases: ["updates", "macos update"], symbol: "arrow.triangle.2.circlepath"),
            .init(title: "Time Machine", extensionName: "TimeMachineSettings",
                  aliases: ["backup", "backups"], symbol: "clock.arrow.circlepath"),
            .init(title: "Printers & Scanners", extensionName: "PrinterScannerSettings",
                  aliases: ["printer", "scanner"], symbol: "printer"),
            .init(title: "Internet Accounts", extensionName: "InternetAccountsSettingsExtension",
                  aliases: ["google account", "email accounts"], symbol: "at"),
            .init(title: "Date & Time", extensionName: "DateAndTime Extension",
                  aliases: ["clock", "time zone"], symbol: "calendar.badge.clock"),
            .init(title: "Sharing", extensionName: "Sharing",
                  aliases: ["file sharing", "airdrop", "remote login"], symbol: "square.and.arrow.up"),
            .init(title: "VPN", extensionName: "VPN",
                  aliases: ["vpn settings"], symbol: "network.badge.shield.half.filled"),
            .init(title: "Lock Screen", extensionName: "LockScreen",
                  aliases: ["lock screen settings", "screen saver"], symbol: "lock.display"),
            .init(title: "About This Mac", extensionName: "AboutExtension",
                  aliases: ["about", "mac details"], symbol: "info.circle")
        ]
        let root = URL(fileURLWithPath: "/System/Library/ExtensionKit/Extensions")
        return descriptions.compactMap { description in
            let bundleURL = root.appendingPathComponent(description.extensionName + ".appex")
            guard let bundle = Bundle(url: bundleURL), let identifier = bundle.bundleIdentifier,
                  let attributes = bundle.infoDictionary?["EXAppExtensionAttributes"] as? [String: Any],
                  let settings = attributes["SettingsExtensionAttributes"] as? [String: Any],
                  settings["allowsXAppleSystemPreferencesURLScheme"] as? Bool == true,
                  let url = URL(string: "x-apple.systempreferences:\(identifier)") else { return nil }
            return SettingsPane(title: description.title, aliases: description.aliases,
                                symbol: description.symbol, id: identifier, url: url)
        }
    }()
}
