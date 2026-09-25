import Foundation

struct EmojiItem: Identifiable {
    let symbol: String
    let name: String
    let keywords: String

    var id: String { symbol }
}

enum EmojiCatalog {
    static let all: [EmojiItem] = {
        var items: [EmojiItem] = []
        var seen = Set<String>()
        func add(_ symbol: String, _ name: String, _ keywords: String = "") {
            guard seen.insert(symbol).inserted else { return }
            items.append(EmojiItem(symbol: symbol, name: name, keywords: keywords))
        }

        let featured: [(String, String, String)] = [
            ("😀", "Grinning Face", "happy smile"), ("😂", "Face With Tears of Joy", "laugh lol funny"),
            ("🥹", "Face Holding Back Tears", "happy crying touched"), ("😍", "Smiling Face With Heart-Eyes", "love crush"),
            ("😊", "Smiling Face With Smiling Eyes", "happy blush"), ("❤️", "Red Heart", "love heart"),
            ("👍", "Thumbs Up", "yes like approve"), ("🙏", "Folded Hands", "thanks thank you prayer please"),
            ("🔥", "Fire", "hot lit"), ("🎉", "Party Popper", "celebrate congratulations confetti"),
            ("🚀", "Rocket", "launch ship"), ("👀", "Eyes", "look see"),
            ("💯", "Hundred Points", "perfect 100"), ("💩", "Pile of Poo", "poop"),
            ("😭", "Loudly Crying Face", "sad crying"), ("👋", "Waving Hand", "hello hi goodbye bye"),
            ("🤔", "Thinking Face", "hmm wonder"), ("🙌", "Raising Hands", "celebrate hooray"),
            ("💀", "Skull", "dead lol"), ("🐶", "Dog Face", "puppy pet"),
            ("🐱", "Cat Face", "kitten pet"), ("🍕", "Pizza", "food"),
            ("☀️", "Sun", "sunny weather"), ("🌈", "Rainbow", "pride weather"),
            ("✨", "Sparkles", "shiny magic"), ("⭐", "Star", "favorite"),
            ("✅", "Check Mark Button", "done yes success"), ("❌", "Cross Mark", "no cancel error")
        ]
        for (symbol, name, keywords) in featured { add(symbol, name, keywords) }

        for value in 0x203C...0x1FAFF {
            guard let scalar = Unicode.Scalar(value), scalar.properties.isEmojiPresentation,
                  !scalar.properties.isEmojiModifier, !(0x1F1E6...0x1F1FF).contains(value),
                  let name = scalar.properties.name else { continue }
            add(String(scalar), name.lowercased().capitalized)
        }

        for region in Locale.Region.isoRegions {
            let code = region.identifier.uppercased()
            let letters = Array(code.utf8)
            guard letters.count == 2, letters.allSatisfy({ (65...90).contains($0) }),
                  let name = Locale.current.localizedString(forRegionCode: code),
                  let first = Unicode.Scalar(0x1F1E6 + Int(letters[0]) - 65),
                  let second = Unicode.Scalar(0x1F1E6 + Int(letters[1]) - 65) else { continue }
            add(String(first) + String(second), "Flag: \(name)", "\(code) country")
        }

        let sequences: [(String, String, String)] = [
            ("👩‍💻", "Woman Technologist", "coding developer computer"),
            ("👨‍💻", "Man Technologist", "coding developer computer"),
            ("🧑‍💻", "Technologist", "coding developer computer"),
            ("👩‍🚀", "Woman Astronaut", "space"), ("👨‍🚀", "Man Astronaut", "space"),
            ("👩‍⚕️", "Woman Health Worker", "doctor nurse"),
            ("👨‍⚕️", "Man Health Worker", "doctor nurse"),
            ("🤷", "Person Shrugging", "shrug idk"),
            ("🤦", "Person Facepalming", "facepalm"),
            ("👨‍👩‍👧", "Family: Man Woman Girl", "parents child"),
            ("🏳️‍🌈", "Rainbow Flag", "pride lgbtq"),
            ("🏳️‍⚧️", "Transgender Flag", "pride"),
            ("❤️‍🔥", "Heart on Fire", "love passion"),
            ("❤️‍🩹", "Mending Heart", "healing love"),
            ("👍🏻", "Thumbs Up: Light Skin Tone", "yes like approve"),
            ("👍🏼", "Thumbs Up: Medium-Light Skin Tone", "yes like approve"),
            ("👍🏽", "Thumbs Up: Medium Skin Tone", "yes like approve"),
            ("👍🏾", "Thumbs Up: Medium-Dark Skin Tone", "yes like approve"),
            ("👍🏿", "Thumbs Up: Dark Skin Tone", "yes like approve"),
            ("1️⃣", "Keycap One", "number 1"), ("2️⃣", "Keycap Two", "number 2"),
            ("3️⃣", "Keycap Three", "number 3"), ("#️⃣", "Keycap Hash", "number")
        ]
        for (symbol, name, keywords) in sequences { add(symbol, name, keywords) }
        return items
    }()
}

enum EmojiSearch {
    static func matches(_ items: [EmojiItem], query: String) -> [EmojiItem] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty else { return items }
        return items.enumerated().compactMap { index, item -> (Int, Int, EmojiItem)? in
            if item.symbol == text { return (10_000, index, item) }
            let name = item.name.lowercased()
            let keywords = item.keywords.lowercased()
            let searchable = name + " " + keywords
            var score = 0
            for word in text.split(whereSeparator: \.isWhitespace) {
                guard let match = Fuzzy.score(searchable, for: String(word)) else { return nil }
                score += match
            }
            let bonus = name.hasPrefix(text) ? 200 : keywords.contains(text) ? 150 : name.contains(text) ? 100 : 0
            return (score + bonus, index, item)
        }.sorted { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 > $1.0 }.map(\.2)
    }
}
