import Foundation

enum ResultOrdering {
    static func order(_ results: [SearchResult], query: String) -> [SearchResult] {
        guard !query.isEmpty else { return results }
        let priority = ["Calculator": 0, "Explorer": 1, "Tools": 2, "Up next": 3]
        func score(_ result: SearchResult) -> Int {
            if case .terminalCommand(let command) = result.kind,
               command.command.lowercased() == query { return 1_000 }
            if result.title.lowercased() == query { return 900 }
            let match = Fuzzy.score(result.title, for: query) ?? -100
            return result.title.lowercased().hasPrefix(query) ? match + 50 : match
        }
        return results.enumerated().sorted { a, b in
            let left = priority[a.element.section] ?? 4
            let right = priority[b.element.section] ?? 4
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
