import AppKit
import Combine
import Foundation

@MainActor final class LauncherModel: ObservableObject {
    @Published var query = "" { didSet { updateSearch() } }
    @Published var fileQuery = "" { didSet { if page == .files { searchFiles() } } }
    @Published var page: LauncherPage = .search
    @Published var settingsTab = 0
    @Published private(set) var results: [SearchResult] = []
    @Published private(set) var fileResults: [URL] = []
    @Published private(set) var searchingFiles = false
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
    private var rateResult: String?
    private var rateFailed = false
    private var usage: SearchUsage
    private var pendingSearch: Task<Void, Never>?
    private var fileSearchTask: Task<Void, Never>?
    private var subscriptions = Set<AnyCancellable>()

    init() {
        usage = UserDefaults.standard.data(forKey: "resultUsage.v1")
            .flatMap { try? JSONDecoder().decode(SearchUsage.self, from: $0) } ?? SearchUsage()
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

    func reset() {
        fileSearchTask?.cancel()
        page = .search
        fileQuery = ""
        fileResults = []
        searchingFiles = false
        query = ""
        presentationID = UUID()
        calendar.refresh()
    }

    func openFileSearch() {
        page = .files
        fileQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func goBack() {
        if page == .files { fileSearchTask?.cancel(); searchingFiles = false }
        page = .search
    }

    private func searchFiles() {
        fileSearchTask?.cancel()
        fileResults = []
        let text = fileQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else { searchingFiles = false; return }
        searchingFiles = true
        fileSearchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            let found = await Task.detached { FileIndex.search(text) }.value
            guard !Task.isCancelled, self?.page == .files,
                  self?.fileQuery.trimmingCharacters(in: .whitespacesAndNewlines) == text else { return }
            self?.fileResults = found
            self?.searchingFiles = false
        }
    }

    private func updateSearch() {
        pendingSearch?.cancel()
        rateResult = nil
        rateFailed = false
        refresh()
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !search.isEmpty else { return }
        guard let request = Conversion.parse(search), Conversion.needsRate(request) else { return }
        pendingSearch = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
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

    func refresh() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()
        var items: [SearchResult] = []
        if let value = Conversion.immediate(text) ?? MathExpression.result(for: text) ?? rateResult {
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
        if ToolSearch.matches(lower, name: "Snippets") {
            items.append(SearchResult(id: "snippetsApplet", title: "Snippets",
                                      subtitle: "Browse and paste saved snippets", symbol: "text.quote",
                                      kind: .snippetsApplet, section: "Tools"))
        }
        if ToolSearch.matches(lower, name: "Clipboard History", aliases: ["clipboard", "clips", "paste history"]) {
            items.append(SearchResult(id: "clipboardApplet", title: "Clipboard History",
                                      subtitle: "Browse and reuse recently copied text", symbol: "doc.on.clipboard",
                                      kind: .clipboardApplet, section: "Tools"))
        }
        if ToolSearch.matches(lower, name: "Emoji Picker", aliases: ["picker", "emojis", "symbols", "reactions"]) {
            items.append(SearchResult(id: "emojiApplet", title: "Emoji Picker",
                                      subtitle: "Search and copy emoji", symbol: "face.smiling",
                                      kind: .emojiApplet, section: "Tools"))
        }
        if ToolSearch.matches(lower, name: "Toggle Appearance",
                              aliases: ["appearance", "light", "dark", "theme"]) {
            items.append(SearchResult(id: "toggleAppearance", title: "Toggle Appearance",
                                      subtitle: "Switch macOS between light and dark mode",
                                      symbol: "circle.lefthalf.filled", kind: .action { [weak self] in
                                          if let error = SystemActions.toggleAppearance() {
                                              self?.message = "Couldn't change appearance: \(error)"
                                          } else {
                                              self?.message = "Appearance changed"
                                          }
                                      }, section: "Tools"))
        }
        if !lower.isEmpty {
            for command in TerminalCommand.allCases where
                Fuzzy.score(command.title + " Ghostty", for: lower) != nil {
                items.append(SearchResult(id: "terminal-\(command.command)", title: command.title,
                                          subtitle: "Run \(command.command) in a new Ghostty tab or window",
                                          symbol: "terminal", kind: .terminalCommand(command),
                                          section: "Applications"))
            }
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
        if !lower.isEmpty {
            for pane in SystemSettingsCatalog.panes where pane.relevance(for: lower) != nil {
                items.append(SearchResult(id: "settingsPane-\(pane.id)", title: pane.title,
                                          subtitle: "Open System Settings", symbol: pane.symbol,
                                          kind: .settingsPane(pane), section: "System Settings"))
            }
        }
        for snippet in preferences.snippets.prefix(lower.isEmpty ? 8 : preferences.snippets.count) {
            if lower.isEmpty || Fuzzy.score(snippet.name + " " + snippet.content, for: lower) != nil {
                items.append(SearchResult(id: snippet.id.uuidString, title: snippet.name,
                                          subtitle: String(snippet.content.prefix(120)), symbol: "text.quote",
                                          kind: .snippet(snippet.content), section: "Snippets"))
            }
        }
        if !lower.isEmpty && Fuzzy.score("settings preferences", for: lower) != nil {
            items.append(SearchResult(id: "settings", title: "Settings", subtitle: "Shortcuts, scripts, snippets & calendar",
                                      symbol: "gearshape", kind: .action { [weak self] in self?.openSettings?() }, section: "Actions"))
        }
        if lower.contains("clear clipboard") {
            items.append(SearchResult(id: "clearClipboard", title: "Clear clipboard history", subtitle: "Remove in-memory entries",
                                      symbol: "trash", kind: .action { [weak self] in self?.clipboard.clear() }, section: "Actions"))
        }
        if !text.isEmpty {
            items.append(SearchResult(id: "googleSearch", title: "Search Google for “\(text)”",
                                      subtitle: "Open in your browser", symbol: "globe",
                                      kind: .webSearch(text), section: "Actions"))
        }
        items.append(SearchResult(id: "fileSearchApplet", title: "Search Files",
                                  subtitle: text.isEmpty ? "Search indexed files" : "Search Spotlight for “\(text)”",
                                  symbol: "doc.text.magnifyingglass", kind: .fileSearchApplet, section: "Actions"))
        results = Array(ResultOrdering.order(items, query: lower, usage: usage).prefix(60))
    }

    func execute(_ result: SearchResult) {
        if case .info = result.kind { return }
        switch result.kind {
        case .application(let url):
            if NSWorkspace.shared.open(url) { remember(result) }
        case .file(let url), .meeting(let url), .explorer(let url):
            NSWorkspace.shared.open(url)
        case .settingsPane(let pane):
            if NSWorkspace.shared.open(pane.url) { remember(result) }
        case .conversion(let value):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
        case .snippet(let value): remember(result); copyText(value, paste: false); return
        case .snippetsApplet: remember(result); page = .snippets; return
        case .clipboardApplet: remember(result); page = .clipboard; return
        case .emojiApplet: remember(result); page = .emoji; return
        case .fileSearchApplet: remember(result); openFileSearch(); return
        case .webSearch(let text):
            guard let url = SearchActions.googleURL(for: text) else { return }
            NSWorkspace.shared.open(url)
        case .terminalCommand(let command):
            if let error = GhosttyLauncher.launch(command) {
                message = "Couldn't open \(command.title): \(error)"
                return
            }
            remember(result)
        case .script(let script): remember(result); run(script)
        case .info: return
        case .action(let action): action()
        }
        hide?()
    }

    private func remember(_ result: SearchResult) {
        usage.record(id: result.id, query: query)
        if let data = try? JSONEncoder().encode(usage) {
            UserDefaults.standard.set(data, forKey: "resultUsage.v1")
        }
        refresh()
    }

    func copyText(_ content: String, paste: Bool) {
        message = nil
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        hide?()
        if paste { pasteIntoPreviousApp?() }
    }

    func openFile(_ url: URL) {
        NSWorkspace.shared.open(url)
        hide?()
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
