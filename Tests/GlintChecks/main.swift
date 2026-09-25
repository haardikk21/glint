import AppKit
import Foundation

func check(_ condition: @autoclosure () -> Bool, _ description: String) {
    guard condition() else {
        fputs("FAIL: \(description)\n", stderr)
        exit(1)
    }
}

check(Conversion.immediate("5 GB to MB") == "5,000 MB", "decimal data units")
check(Conversion.immediate("32 F to C") == "0 °C", "temperature")
check(Conversion.immediate("0 C to K") == "273.15 K", "kelvin")
check(Conversion.immediate("5 USD to USD") == "5 USD", "same currency")
check(Conversion.immediate("0xFF") == "255", "hex decode is just the number")
check(Conversion.immediate("hex 0xFF") == "255", "explicit hex decode")
check(Conversion.immediate("base64 SGVsbG8=") == "Hello", "base64 decode")
check(Conversion.immediate("decimal 255") == "0xFF", "decimal to hex")
check(Conversion.immediate("base64 !invalid!") == nil, "invalid base64")
check(Conversion.needsRate(Conversion.parse("5 USD to CAD")!), "fiat rate")
check(Conversion.needsRate(Conversion.parse("234 ETH to USD")!), "crypto rate")
check(!Conversion.needsRate(Conversion.parse("5 GB to MB")!), "local unit conversion")
check(!Conversion.needsRate(Conversion.parse("1 ETH to BTC")!), "unsupported crypto pair")
check(Conversion.parse("some random search") == nil, "unrelated input")
check(Fuzzy.score("Google Chrome", for: "gch") != nil, "fuzzy app name")
check(Fuzzy.score("Google Chrome", for: "firefox") == nil, "fuzzy non-match")
let hash = "0x" + String(repeating: "a", count: 64)
let destinations = Blockchain.destinations(for: "  \(hash)\n")
check(destinations.count == 4, "hash has transaction and block options on both networks")
check(destinations[0].url.absoluteString == "https://basescan.org/tx/\(hash)", "mainnet transaction URL")
check(destinations[3].url.absoluteString == "https://sepolia.basescan.org/block/\(hash)", "Sepolia block URL")
check(Blockchain.destinations(for: "0x1234").isEmpty, "invalid hash")
let address = "0x" + String(repeating: "a", count: 40)
let addressDestinations = Blockchain.destinations(for: "\n\(address) ")
check(addressDestinations.count == 2, "address has mainnet and Sepolia options")
check(addressDestinations[0].url.absoluteString == "https://basescan.org/address/\(address)", "mainnet address URL")
check(addressDestinations[1].url.absoluteString == "https://sepolia.basescan.org/address/\(address)", "Sepolia address URL")
check(Blockchain.destinations(for: address + "a").isEmpty, "reject non-address length")
let calculation = SearchResult(id: "calc", title: "5,000 MB", subtitle: "", symbol: "", kind: .conversion("5,000 MB"), section: "Calculator")
let app = SearchResult(id: "app", title: "1Password", subtitle: "", symbol: "", kind: .application(URL(fileURLWithPath: "/Applications/1Password.app")), section: "Applications")
check(ResultOrdering.order([app, calculation], query: "5 GB to MB").first?.id == "calc", "conversion outranks apps")
let fileSearch = SearchResult(id: "fileSearchApplet", title: "Search Files", subtitle: "", symbol: "",
                              kind: .fileSearchApplet, section: "Actions")
check(ResultOrdering.order([fileSearch, app], query: "1Password").first?.id == "app",
      "application matches appear before the file-search action")
let openCode = SearchResult(id: "oc", title: "OpenCode", subtitle: "", symbol: "",
                            kind: .terminalCommand(.openCode), section: "Applications")
let docker = SearchResult(id: "docker", title: "Docker", subtitle: "", symbol: "",
                          kind: .application(URL(fileURLWithPath: "/Applications/Docker.app")), section: "Applications")
check(ResultOrdering.order([docker, openCode], query: "oc").first?.id == "oc",
      "OpenCode command alias outranks partial app matches")
check(!ToolSearch.matches("pi", name: "Emoji Picker", aliases: ["picker", "emojis"]),
      "Pi search does not get eclipsed by Emoji Picker")
check(!ToolSearch.matches("oc", name: "Toggle Appearance", aliases: ["light", "dark"]),
      "OpenCode search does not get eclipsed by appearance")
check(ToolSearch.matches("dark", name: "Toggle Appearance", aliases: ["light", "dark"]),
      "dark mode finds appearance toggle")
check(ToolSearch.matches("emoji", name: "Emoji Picker", aliases: ["emojis"]),
      "emoji finds the picker")
check(ApplicationIndex.load().contains(where: { $0.lastPathComponent == "Finder.app" }),
      "Finder is indexed alongside Applications")
func compiles(_ source: String) -> Bool {
    guard let script = NSAppleScript(source: source) else { return false }
    var error: NSDictionary?
    return script.compileAndReturnError(&error)
}
check(compiles(SystemActions.appearanceScript), "macOS appearance toggle AppleScript compiles")
if FileManager.default.fileExists(atPath: "/Applications/Ghostty.app/Contents/Resources/Ghostty.sdef") {
    check(compiles(GhosttyLauncher.script(for: .pi)), "Ghostty Pi tab/window automation compiles")
    check(compiles(GhosttyLauncher.script(for: .openCode)), "Ghostty OpenCode tab/window automation compiles")
}
let applet = SearchResult(id: "snippetsApplet", title: "Snippets", subtitle: "", symbol: "",
                          kind: .snippetsApplet, section: "Tools")
check(ResultOrdering.order([app, applet], query: "snippets").first?.id == "snippetsApplet", "Snippets command outranks apps")
let emojis = EmojiCatalog.all
check(emojis.count > 1400, "Unicode emoji and country flags are available offline")
check(EmojiSearch.matches(emojis, query: "rocket").first?.symbol == "🚀", "emoji search finds names")
check(EmojiSearch.matches(emojis, query: "poop").first?.symbol == "💩", "emoji search finds aliases")
check(EmojiSearch.matches(emojis, query: "US flag").contains(where: { $0.symbol == "🇺🇸" }),
      "emoji search matches region codes across unordered words")
let emojiIDs = (0..<12).map(String.init)
check(LauncherNavigation.nextEmojiID("0", in: emojiIDs, columns: 9, moving: .down) == "9",
      "Down moves one grid row")
check(LauncherNavigation.nextEmojiID("5", in: emojiIDs, columns: 9, moving: .down) == "5",
      "Down stays put when the next row has no cell")
check(LauncherNavigation.nextEmojiID("9", in: emojiIDs, columns: 9, moving: .up) == "0",
      "Up moves one grid row")
let snippets = [Snippet(name: "Status", content: "deployment progress"),
                Snippet(name: "Deploy checklist", content: "check the rollout dashboard")]
check(SnippetSearch.matches(snippets, query: "deploy").map(\.name) == ["Deploy checklist", "Status"],
      "snippet name matches outrank content matches")
check(SnippetSearch.matches(snippets, query: "rollout").map(\.name) == ["Deploy checklist"],
      "snippet content is searchable")
check(SnippetSearch.matches(snippets, query: "missing").isEmpty, "unmatched snippets are excluded")
let ids = ["app", "file", "snippet"]
check(LauncherNavigation.direction(for: 125, modifiers: []) == .down, "unmodified Down is navigation")
check(LauncherNavigation.direction(for: 126, modifiers: []) == .up, "unmodified Up is navigation")
check(LauncherNavigation.direction(for: 125, modifiers: [.option]) == nil, "modified arrows remain text editing")
check(LauncherNavigation.snippetPaste(for: 36, modifiers: []) == false, "Return copies snippet")
check(LauncherNavigation.snippetPaste(for: 36, modifiers: [.shift]) == true, "Shift-Return pastes snippet")
check(LauncherNavigation.snippetPaste(for: 76, modifiers: [.shift]) == true, "keypad Shift-Enter pastes snippet")
check(LauncherNavigation.snippetPaste(for: 36, modifiers: [.command]) == nil, "Command-Return is not intercepted")
check(LauncherNavigation.nextID(nil, in: ids, moving: .down) == "app", "Down selects first result")
check(LauncherNavigation.nextID("app", in: ids, moving: .down) == "file", "Down advances one result")
check(LauncherNavigation.nextID("file", in: ids, moving: .up) == "app", "Up returns one result")
check(LauncherNavigation.nextID("snippet", in: ids, moving: .down) == "snippet", "Down stops at end")
check(LauncherNavigation.nextID("removed", in: ids, moving: .up) == "app", "stale selection resolves to first result")
check(LauncherNavigation.nextID(nil, in: [], moving: .down) == nil, "empty results ignore navigation")
let meet = MeetingLinks.first(in: [nil, "Join https://meet.google.com/abc-defg-hij."])
check(meet?.absoluteString == "https://meet.google.com/abc-defg-hij", "meeting URL in notes")
check(MeetingLinks.first(in: ["https://acme.zoom.us/j/123?pwd=abc"])?.host == "acme.zoom.us", "Zoom subdomain")
check(MeetingLinks.first(in: ["https://meet.google.com.evil.example/abc"]) == nil, "reject lookalike host")
check(MeetingLinks.first(in: ["http://meet.google.com/abc"]) == nil, "require HTTPS")
check(MeetingLinks.first(in: ["https://meet.google.com/first", "https://zoom.us/second"])?.host == "meet.google.com", "prefer event URL")
print("64 checks passed")
