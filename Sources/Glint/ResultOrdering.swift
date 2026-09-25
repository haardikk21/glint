import Foundation

enum ResultOrdering {
    static func order(_ results: [SearchResult], query: String) -> [SearchResult] {
        guard !query.isEmpty else { return results }
        let priority = ["Calculator": 0, "Explorer": 1, "Tools": 2, "Up next": 3]
        return results.enumerated().sorted { a, b in
            let left = priority[a.element.section] ?? 4
            let right = priority[b.element.section] ?? 4
            if left != right { return left < right }
            let aScore = Fuzzy.score(a.element.title, for: query) ?? -100
            let bScore = Fuzzy.score(b.element.title, for: query) ?? -100
            if aScore != bScore { return aScore > bScore }
            return a.offset < b.offset
        }.map(\.element)
    }
}
