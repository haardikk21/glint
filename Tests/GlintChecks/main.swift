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
check(Conversion.immediate("0xFF") == "255 decimal", "hex decode")
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
let calculation = SearchResult(id: "calc", title: "5,000 MB", subtitle: "", symbol: "", kind: .conversion("5,000 MB"), section: "Calculator")
let app = SearchResult(id: "app", title: "1Password", subtitle: "", symbol: "", kind: .application(URL(fileURLWithPath: "/Applications/1Password.app")), section: "Applications")
check(ResultOrdering.order([app, calculation], query: "5 GB to MB").first?.id == "calc", "conversion outranks apps")
let ids = ["app", "file", "snippet"]
check(LauncherNavigation.direction(for: 125, modifiers: []) == .down, "unmodified Down is navigation")
check(LauncherNavigation.direction(for: 126, modifiers: []) == .up, "unmodified Up is navigation")
check(LauncherNavigation.direction(for: 125, modifiers: [.option]) == nil, "modified arrows remain text editing")
check(LauncherNavigation.nextID(nil, in: ids, moving: .down) == "app", "Down selects first result")
check(LauncherNavigation.nextID("app", in: ids, moving: .down) == "file", "Down advances one result")
check(LauncherNavigation.nextID("file", in: ids, moving: .up) == "app", "Up returns one result")
check(LauncherNavigation.nextID("snippet", in: ids, moving: .down) == "snippet", "Down stops at end")
check(LauncherNavigation.nextID("removed", in: ids, moving: .up) == "app", "stale selection resolves to first result")
check(LauncherNavigation.nextID(nil, in: [], moving: .down) == nil, "empty results ignore navigation")
let now = Date()
let iso = ISO8601DateFormatter()
let eventJSON = """
{"summary":"Team sync","start":{"dateTime":"\(iso.string(from: now.addingTimeInterval(60)))"},
 "end":{"dateTime":"\(iso.string(from: now.addingTimeInterval(1860)))"},
 "description":"Join https://meet.google.com/abc-defg-hij"}
"""
let event = try! JSONDecoder().decode(GoogleCalendarModels.Event.self, from: Data(eventJSON.utf8))
check(GoogleCalendarModels.meeting(from: event, now: now)?.url.host == "meet.google.com", "Google meeting link")
let fakeLink = eventJSON.replacingOccurrences(of: "meet.google.com/", with: "meet.google.com.evil.example/")
let fakeEvent = try! JSONDecoder().decode(GoogleCalendarModels.Event.self, from: Data(fakeLink.utf8))
check(GoogleCalendarModels.meeting(from: fakeEvent, now: now) == nil, "reject lookalike meeting host")
let declined = eventJSON.replacingOccurrences(of: "\"summary\"", with: "\"attendees\":[{\"self\":true,\"responseStatus\":\"declined\"}],\"summary\"")
let declinedEvent = try! JSONDecoder().decode(GoogleCalendarModels.Event.self, from: Data(declined.utf8))
check(GoogleCalendarModels.meeting(from: declinedEvent, now: now) == nil, "skip declined meeting")
let (socket, port) = try! LoopbackReceiver.listen()
DispatchQueue.global().async {
    let url = URL(string: "http://127.0.0.1:\(port)/oauth2callback?state=nonce&code=sample")!
    _ = try? Data(contentsOf: url)
}
check((try! LoopbackReceiver.receive(socket: socket, state: "nonce")) == "sample", "loopback OAuth callback")
print("33 checks passed")
