import Foundation

enum ResultOrdering {
    static func order(_ results: [SearchResult], query: String, usage: SearchUsage = SearchUsage()) -> [SearchResult] {
        guard !query.isEmpty else { return results }
        let priority = ["Calculator": 0, "Explorer": 1, "Tools": 2, "Up next": 3]
        let now = Date()
        func group(_ result: SearchResult) -> Int {
            switch result.kind {
            case .webSearch, .fileSearchApplet: return 10
            default: return priority[result.section] ?? 4
            }
        }
        func score(_ result: SearchResult) -> Int {
            let familiarity = usage.boost(id: result.id, query: query, at: now)
            if case .terminalCommand(let command) = result.kind,
               command.command.lowercased() == query { return 1_000 + familiarity }
            if case .settingsPane(let pane) = result.kind {
                return (pane.relevance(for: query) ?? -100) + familiarity
            }
            if result.title.lowercased() == query { return 900 + familiarity }
            let match = Fuzzy.score(result.title, for: query) ?? -100
            if result.title.lowercased().hasPrefix(query) {
                return match + 50 - max(0, result.title.count - query.count) + familiarity
            }
            return match + familiarity
        }
        return results.enumerated().sorted { a, b in
            let left = group(a.element)
            let right = group(b.element)
            if left != right { return left < right }
            let aScore = score(a.element)
            let bScore = score(b.element)
            if aScore != bScore { return aScore > bScore }
            return a.offset < b.offset
        }.map(\.element)
    }
}

enum ToolSearch {
    static func matches(_ query: String, name: String, aliases: [String] = []) -> Bool {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if text.isEmpty || name.lowercased().hasPrefix(text) { return true }
        guard text.count >= 3 else { return false }
        return aliases.contains { $0.lowercased().hasPrefix(text) }
    }
}
