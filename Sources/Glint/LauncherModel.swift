import AppKit
import Combine
import Foundation

@MainActor final class LauncherModel: ObservableObject {
    @Published var query = "" { didSet { updateSearch() } }
    @Published var page: LauncherPage = .search
    @Published var settingsTab = 0
    @Published private(set) var results: [SearchResult] = []
    @Published private(set) var presentationID = UUID()
    @Published var message: String?

    let preferences = Preferences()
    let clipboard = ClipboardMonitor()
    let calendar = CalendarService()
    var hide: (() -> Void)?
    var openSettings: (() -> Void)?
    var openSnippetSettings: (() -> Void)?
    var pasteIntoPreviousApp: (() -> Void)?

    private var applications: [URL] = []
    private var files: [URL] = []
    private var rateResult: String?
    private var rateFailed = false
    private var pendingSearch: Task<Void, Never>?
    private var subscriptions = Set<AnyCancellable>()

    init() {
        clipboard.start()
        preferences.$scripts.dropFirst().sink { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }.store(in: &subscriptions)
        preferences.$snippets.dropFirst().sink { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }.store(in: &subscriptions)
        clipboard.$entries.dropFirst().sink { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }.store(in: &subscriptions)
        calendar.$meeting.dropFirst().sink { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }.store(in: &subscriptions)
        Task { [weak self] in
            let apps = await Task.detached { ApplicationIndex.load() }.value
            self?.applications = apps
            self?.refresh()
        }
        refresh()
    }

    func reset() { page = .search; query = ""; presentationID = UUID(); calendar.refresh() }

    private func updateSearch() {
        pendingSearch?.cancel()
        files = []
        rateResult = nil
        rateFailed = false
        refresh()
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !search.isEmpty else { return }
        pendingSearch = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            if search.count >= 2 && Conversion.immediate(search) == nil &&
                !(Conversion.parse(search).map(Conversion.needsRate) ?? false) &&
                Blockchain.destinations(for: search).isEmpty {
                let found = await Task.detached { FileIndex.search(search) }.value
                guard !Task.isCancelled, self?.query == search else { return }
                self?.files = found
                self?.refresh()
            }
            if let request = Conversion.parse(search), Conversion.needsRate(request) {
                do {
                    let value = try await Conversion.rate(request)
                    guard !Task.isCancelled, self?.query == search else { return }
                    self?.rateResult = value
                    self?.rateFailed = false
                } catch {
                    guard !Task.isCancelled, self?.query == search else { return }
                    self?.rateResult = "Rate unavailable — check connection"
                    self?.rateFailed = true
                }
                self?.refresh()
            }
        }
    }

    func refresh() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()
        var items: [SearchResult] = []
        if let value = Conversion.immediate(text) ?? rateResult {
            items.append(SearchResult(id: "conversion", title: value,
                                      subtitle: rateFailed ? text : "Copy result · \(text)",
                                      symbol: "equal.circle", kind: rateFailed ? .info : .conversion(value),
                                      section: "Calculator"))
        } else if let request = Conversion.parse(text), Conversion.needsRate(request) {
            items.append(SearchResult(id: "ratePending", title: "Fetching exchange rate…",
                                      subtitle: text, symbol: "arrow.triangle.2.circlepath",
                                      kind: .info, section: "Calculator"))
        }
        let hashInput = text.isEmpty ? clipboard.entries.first?.text ?? "" : text
        for destination in Blockchain.destinations(for: hashInput) {
            items.append(SearchResult(id: destination.url.absoluteString, title: destination.title,
                                      subtitle: destination.url.absoluteString, symbol: "link",
                                      kind: .explorer(destination.url), section: "Explorer"))
        }
        if let meeting = calendar.meeting {
            let title = "Join \(meeting.title)"
            if lower.isEmpty || Fuzzy.score(title, for: lower) != nil || lower.contains("meeting") {
                items.append(SearchResult(id: "meeting", title: title,
                                          subtitle: "\(meeting.start.formatted(date: .omitted, time: .shortened)) · \(meeting.url.host ?? "")",
                                          symbol: "video", kind: .meeting(meeting.url), section: "Up next"))
            }
        }
        if lower.isEmpty || Fuzzy.score("Snippets", for: lower) != nil {
            items.append(SearchResult(id: "snippetsApplet", title: "Snippets",
                                      subtitle: "Browse and paste saved snippets", symbol: "text.quote",
                                      kind: .snippetsApplet, section: "Tools"))
        }
        var appCount = 0
        for app in applications {
            let name = app.deletingPathExtension().lastPathComponent
            if lower.isEmpty || Fuzzy.score(name, for: lower) != nil {
                items.append(SearchResult(id: app.path, title: name, subtitle: "Application",
                                          symbol: "app", kind: .application(app), section: "Applications"))
                appCount += 1
                if appCount >= (lower.isEmpty ? 12 : 30) { break }
            }
        }
        for script in preferences.scripts.prefix(lower.isEmpty ? 8 : preferences.scripts.count) {
            if lower.isEmpty || Fuzzy.score(script.name, for: lower) != nil {
                items.append(SearchResult(id: script.id.uuidString, title: script.name,
                                          subtitle: "Run script", symbol: "terminal",
                                          kind: .script(script), section: "Scripts"))
            }
        }
        for snippet in preferences.snippets.prefix(lower.isEmpty ? 8 : preferences.snippets.count) {
            if lower.isEmpty || Fuzzy.score(snippet.name + " " + snippet.content, for: lower) != nil {
                items.append(SearchResult(id: snippet.id.uuidString, title: snippet.name,
                                          subtitle: String(snippet.content.prefix(120)), symbol: "text.quote",
                                          kind: .snippet(snippet.content), section: "Snippets"))
            }
        }
        if !lower.isEmpty {
            for file in files where Fuzzy.score(file.lastPathComponent, for: lower) != nil {
                items.append(SearchResult(id: file.path, title: file.lastPathComponent,
                                          subtitle: file.deletingLastPathComponent().path,
                                          symbol: "doc", kind: .file(file), section: "Files"))
            }
        }
        let clipboardMatches = clipboard.entries.filter {
            lower.isEmpty || lower.contains("clip") || Fuzzy.score(String($0.text.prefix(500)), for: lower) != nil
        }
        for entry in clipboardMatches.prefix(lower.isEmpty ? 6 : 10) {
            items.append(SearchResult(id: entry.id.uuidString,
                                      title: String(entry.text.replacingOccurrences(of: "\n", with: " ").prefix(90)),
                                      subtitle: "Clipboard · \(entry.date.formatted(date: .omitted, time: .shortened))",
                                      symbol: "doc.on.clipboard", kind: .clipboard(entry.text), section: "Clipboard"))
        }
        if !lower.isEmpty && Fuzzy.score("settings preferences", for: lower) != nil {
            items.append(SearchResult(id: "settings", title: "Settings", subtitle: "Shortcuts, scripts, snippets & calendar",
                                      symbol: "gearshape", kind: .action { [weak self] in self?.openSettings?() }, section: "Actions"))
        }
        if lower.contains("clear clipboard") {
            items.append(SearchResult(id: "clearClipboard", title: "Clear clipboard history", subtitle: "Remove in-memory entries",
                                      symbol: "trash", kind: .action { [weak self] in self?.clipboard.clear() }, section: "Actions"))
        }
        results = Array(ResultOrdering.order(items, query: lower).prefix(60))
    }

    func execute(_ result: SearchResult) {
        if case .info = result.kind { return }
        switch result.kind {
        case .application(let url), .file(let url), .meeting(let url), .explorer(let url):
            NSWorkspace.shared.open(url)
        case .conversion(let value), .clipboard(let value):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
        case .snippet(let value): copySnippet(value, paste: false); return
        case .snippetsApplet: page = .snippets; return
        case .script(let script): run(script)
        case .info: return
        case .action(let action): action()
        }
        hide?()
    }

    func copySnippet(_ content: String, paste: Bool) {
        message = nil
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        hide?()
        if paste { pasteIntoPreviousApp?() }
    }

    func run(_ script: ScriptCommand) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", script.script]
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            message = "Started \(script.name)"
            hide?()
        } catch { message = "Couldn't run \(script.name): \(error.localizedDescription)" }
    }
}
