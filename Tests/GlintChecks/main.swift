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
check(Conversion.parse("USD to CAD") == Conversion.Request(amount: 1, source: "USD", destination: "CAD"),
      "currency pair defaults to one unit")
check(Conversion.needsRate(Conversion.parse("usd to cad")!), "amount-free fiat rate")
check(Conversion.needsRate(Conversion.parse("ETH to USD")!), "amount-free crypto rate")
check(Conversion.immediate("GB to MB") == "1,000 MB", "amount-free unit conversion")
check(Conversion.parse("foo to bar") == nil, "unrelated words do not become conversions")
check(Conversion.parse("378s to minutes") == Conversion.Request(amount: 378, source: "S", destination: "MINUTES"),
      "attached second unit parses with its amount")
check(Conversion.immediate("378s to minutes") == "6.3 minutes", "seconds to minutes")
check(Conversion.immediate("60s to min") == "1 minute", "singular minute output")
check(Conversion.immediate("1.5h to minutes") == "90 minutes", "attached decimal hours")
check(Conversion.immediate("250ms to seconds") == "0.25 seconds", "milliseconds to seconds")
check(Conversion.immediate("90 seconds to minutes") == "1.5 minutes", "spaced time units")
check(Conversion.immediate("2 days to hours") == "48 hours", "days to hours")
check(Conversion.immediate("5GB to MB") == "5,000 MB", "attached storage units")
check(Conversion.parse("378foo to minutes") == nil, "unknown attached units are ignored")
check(Conversion.needsRate(Conversion.parse("234 ETH to USD")!), "crypto rate")
check(!Conversion.needsRate(Conversion.parse("5 GB to MB")!), "local unit conversion")
check(!Conversion.needsRate(Conversion.parse("1 ETH to BTC")!), "unsupported crypto pair")
check(Conversion.parse("some random search") == nil, "unrelated input")
check(Fuzzy.score("Google Chrome", for: "gch") != nil, "fuzzy app name")
check(Fuzzy.score("Google Chrome", for: "firefox") == nil, "fuzzy non-match")
check(MathExpression.result(for: "1+2*3") == "7", "multiplication precedes addition")
check(MathExpression.result(for: "((1+2)*3)/6") == "1.5", "nested parentheses")
check(MathExpression.result(for: "10-6/2") == "7", "division precedes subtraction")
check(MathExpression.result(for: "10 % 3") == "1", "remainder operation")
check(MathExpression.result(for: "-4*(2+3)") == "-20", "unary minus and parentheses")
check(MathExpression.result(for: "2--3") == "5", "unary minus after subtraction")
check(MathExpression.result(for: "12/4/3") == "1", "left-associative division")
check(MathExpression.result(for: ".5+.25") == "0.75", "fractional decimal arithmetic")
check(MathExpression.result(for: "(1+2)*(3-4)") == "-3", "multiple parenthesized terms")
check(MathExpression.result(for: "0.1+0.2") == "0.3", "floating results are formatted")
check(MathExpression.result(for: "1e3+2") == "1,002", "scientific notation")
check(MathExpression.result(for: "1/0") == nil, "division by zero is rejected")
check(MathExpression.result(for: "5%0") == nil, "remainder by zero is rejected")
check(MathExpression.result(for: "(1+2") == nil, "unbalanced parentheses are rejected")
check(MathExpression.result(for: "1+") == nil, "incomplete expressions are rejected")
check(MathExpression.result(for: "5") == nil, "plain numbers do not create calculator results")
check(MathExpression.result(for: "5 USD to CAD") == nil, "currency input is not treated as math")
check(MathExpression.result(for: "1e308*1e308") == nil, "overflow is rejected")
check(MathExpression.result(for: "2^3") == nil, "unsupported operators are rejected")
let deeplyNested = String(repeating: "(", count: 65) + "1+2" + String(repeating: ")", count: 65)
check(MathExpression.result(for: deeplyNested) == nil, "nested expressions are bounded")
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
let screenshot = SearchResult(id: "screenshot", title: "Screenshot", subtitle: "", symbol: "",
                              kind: .application(URL(fileURLWithPath: "/System/Applications/Utilities/Screenshot.app")),
                              section: "Applications")
let sharing = SearchResult(id: "screenSharing", title: "Screen Sharing", subtitle: "", symbol: "",
                           kind: .application(URL(fileURLWithPath: "/System/Applications/Utilities/Screen Sharing.app")),
                           section: "Applications")
check(ResultOrdering.order([sharing, screenshot], query: "screen").first?.id == screenshot.id,
      "shorter Screenshot match beats alphabetical Screen Sharing")
var usage = SearchUsage()
let now = Date()
usage.record(id: sharing.id, query: "screen", at: now)
check(ResultOrdering.order([sharing, screenshot], query: "screen", usage: usage).first?.id == sharing.id,
      "recent selection wins the next matching search")
for _ in 0..<5 { usage.record(id: screenshot.id, query: "screen", at: now) }
check(ResultOrdering.order([sharing, screenshot], query: "screen", usage: usage).first?.id == screenshot.id,
      "frequently chosen Screenshot wins over occasional Screen Sharing")
let restoredUsage = try! JSONDecoder().decode(SearchUsage.self, from: JSONEncoder().encode(usage))
check(ResultOrdering.order([sharing, screenshot], query: "screen", usage: restoredUsage).first?.id == screenshot.id,
      "search preference survives persistence")
let fileSearch = SearchResult(id: "fileSearchApplet", title: "Search Files", subtitle: "", symbol: "",
                              kind: .fileSearchApplet, section: "Actions")
check(ResultOrdering.order([fileSearch, app], query: "1Password").first?.id == "app",
      "application matches appear before the file-search action")
let googleURL = SearchActions.googleURL(for: "  why is 1+1 & 2?  ")!
check(googleURL.scheme == "https" && googleURL.host == "www.google.com" &&
      URLComponents(url: googleURL, resolvingAgainstBaseURL: false)?.queryItems?.first?.value == "why is 1+1 & 2?",
      "Google fallback preserves and encodes the search query")
let googleSearch = SearchResult(id: "googleSearch", title: "Search Google for randomquery", subtitle: "", symbol: "",
                                kind: .webSearch("randomquery"), section: "Actions")
check(ResultOrdering.order([fileSearch, googleSearch], query: "randomquery").first?.id == "googleSearch",
      "Google is the first fallback when nothing matches")
check(ResultOrdering.order([googleSearch, app], query: "1Password").first?.id == "app",
      "matching apps outrank Google fallback")
check(ResultOrdering.order([googleSearch, fileSearch], query: "Search Files").first?.id == "fileSearchApplet",
      "explicit Search Files query selects file mode")
let panes = SystemSettingsCatalog.panes
check(panes.count >= 20, "macOS exposes a broad set of directly addressable settings panes")
for (title, identifier) in [
    ("Accessibility", "com.apple.Accessibility-Settings.extension"),
    ("Privacy & Security", "com.apple.settings.PrivacySecurity.extension"),
    ("Storage", "com.apple.settings.Storage"),
    ("Displays", "com.apple.Displays-Settings.extension"),
    ("Mouse", "com.apple.Mouse-Settings.extension")
] {
    check(panes.first(where: { $0.title == title })?.url.absoluteString == "x-apple.systempreferences:\(identifier)",
          "\(title) opens its installed settings extension")
}
check(panes.first(where: { $0.title == "Privacy & Security" })?.relevance(for: "privacy security") != nil,
      "privacy and security can be found without an ampersand")
check(panes.first(where: { $0.title == "Displays" })?.relevance(for: "display settings") != nil,
      "display settings query finds Displays")
if let screenTime = panes.first(where: { $0.title == "Screen Time" }) {
    let pane = SearchResult(id: screenTime.id, title: screenTime.title, subtitle: "", symbol: "",
                            kind: .settingsPane(screenTime), section: "System Settings")
    check(ResultOrdering.order([pane, screenshot], query: "screen").first?.id == screenshot.id,
          "Screenshot remains ahead of Screen Time settings")
}
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
let indexedApps = ApplicationIndex.load()
check(indexedApps.contains(where: { $0.lastPathComponent == "Finder.app" }),
      "Finder is indexed alongside Applications")
let screenApps = indexedApps.compactMap { url -> SearchResult? in
    let name = url.deletingPathExtension().lastPathComponent
    guard Fuzzy.score(name, for: "screen") != nil else { return nil }
    return SearchResult(id: url.path, title: name, subtitle: "", symbol: "",
                        kind: .application(url), section: "Applications")
}
check(ResultOrdering.order(screenApps, query: "screen").first?.title == "Screenshot",
      "actual installed Screenshot app is the first screen search result")
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
print("116 checks passed")
