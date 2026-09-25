import Foundation

enum SnippetSearch {
    static func matches(_ snippets: [Snippet], query: String) -> [Snippet] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return snippets }
        return snippets.enumerated().compactMap { index, snippet -> (Int, Int, Snippet)? in
            if let score = Fuzzy.score(snippet.name, for: text) { return (score + 100, index, snippet) }
            if let score = Fuzzy.score(String(snippet.content.prefix(5000)), for: text) {
                return (score, index, snippet)
            }
            return nil
        }.sorted { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 > $1.0 }.map(\.2)
    }
}
