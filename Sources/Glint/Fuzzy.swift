enum Fuzzy {
    static func score(_ candidate: String, for query: String) -> Int? {
        let needle = Array(query.lowercased())
        if needle.isEmpty { return 0 }
        let haystack = Array(candidate.lowercased())
        var position = 0
        var score = 0
        var previous = -2
        for character in needle {
            guard let match = haystack.indices.dropFirst(position).first(where: { haystack[$0] == character }) else {
                return nil
            }
            score += match == previous + 1 ? 5 : 1
            if match == 0 || !haystack[match - 1].isLetter { score += 4 }
            previous = match
            position = match + 1
        }
        return score - haystack.count / 8
    }
}
