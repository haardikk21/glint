import Foundation

struct SearchUsage: Codable {
    struct Entry: Codable {
        var count: Int
        var lastUsed: Date
    }

    private(set) var results: [String: Entry] = [:]
    private(set) var queries: [String: [String: Entry]] = [:]

    mutating func record(id: String, query: String, at date: Date = Date()) {
        var entry = results[id] ?? Entry(count: 0, lastUsed: date)
        entry.count = min(entry.count + 1, 10_000)
        entry.lastUsed = date
        results[id] = entry
        if results.count > 300, let oldest = results.min(by: { $0.value.lastUsed < $1.value.lastUsed })?.key {
            results.removeValue(forKey: oldest)
        }

        guard let key = Self.searchKey(query) else { return }
        var choices = queries[key] ?? [:]
        var choice = choices[id] ?? Entry(count: 0, lastUsed: date)
        choice.count = min(choice.count + 1, 10_000)
        choice.lastUsed = date
        choices[id] = choice
        if choices.count > 20, let oldest = choices.min(by: { $0.value.lastUsed < $1.value.lastUsed })?.key {
            choices.removeValue(forKey: oldest)
        }
        queries[key] = choices
        if queries.count > 100, let oldest = queries.min(by: {
            ($0.value.values.map(\.lastUsed).max() ?? .distantPast) <
                ($1.value.values.map(\.lastUsed).max() ?? .distantPast)
        })?.key {
            queries.removeValue(forKey: oldest)
        }
    }

    func boost(id: String, query: String, at date: Date = Date()) -> Int {
        var score = 0
        if let entry = results[id] {
            score += min(entry.count, 5) * 3
            let age = date.timeIntervalSince(entry.lastUsed)
            if age < 86_400 { score += 12 }
            else if age < 7 * 86_400 { score += 6 }
        }
        if let key = Self.searchKey(query), let choice = queries[key]?[id] {
            score += min(choice.count, 12) * 35
        }
        return score
    }

    private static func searchKey(_ query: String) -> String? {
        let text = query.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !text.isEmpty, text.count <= 40,
              text.allSatisfy({ $0.isLetter || $0.isNumber || $0 == " " }) else { return nil }
        return text
    }
}
