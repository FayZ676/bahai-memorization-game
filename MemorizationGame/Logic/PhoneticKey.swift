import Foundation

enum PhoneticKey {
    static func encode(_ token: some StringProtocol) -> String {
        if String(token.filter { $0.isLetter || $0.isNumber }) == "0" { return "o" }
        let prepared = prepared(token)
        guard !prepared.isEmpty else { return "" }
        return String(collapsingRepeats(droppingInteriorVowels(sounds(prepared))))
    }

    static func matches(_ spoken: String, _ reference: String) -> Bool {
        guard !spoken.isEmpty, !reference.isEmpty else { return false }
        guard spoken != reference else { return true }
        if acceptedRenderings[reference]?.contains(spoken) == true { return true }
        guard sharesOnset(spoken, reference) else { return false }
        let tolerance: Int
        switch reference.count {
        case 1...5: tolerance = 1
        default: tolerance = 2
        }
        return distance(spoken, reference, limit: tolerance) <= tolerance
    }

    private static func sharesOnset(_ spoken: String, _ reference: String) -> Bool {
        guard let first = spoken.first, let second = reference.first else { return false }
        guard !vowels.contains(first), !vowels.contains(second) else { return true }
        return first == second
    }

    private static let archaicRenderings: [(written: String, spoken: [String])] = [
        ("thou", ["our", "be", "they", "though"]),
        ("thee", ["the", "be", "they"]),
        ("thy", ["the", "they", "my"]),
        ("thine", ["mine"]),
        ("thyself", ["myself"]),
        ("my", ["thy", "thee", "thou"]),
    ]

    private static let acceptedRenderings: [String: Set<String>] = {
        var result: [String: Set<String>] = [:]
        for entry in archaicRenderings {
            result[encode(entry.written), default: []].formUnion(entry.spoken.map(encode))
        }
        for (written, spoken) in result {
            result[written] = spoken.subtracting([written])
        }
        return result
    }()

    private static let foldingLocale = Locale(identifier: "en_US")
    private static let vowels: Set<Character> = ["a", "e", "i", "o", "u"]

    private static let digitWords: [[Character]] = [
        Array("zero"), Array("one"), Array("two"), Array("three"), Array("four"),
        Array("five"), Array("six"), Array("seven"), Array("eight"), Array("nine"),
    ]

    private static func prepared(_ token: some StringProtocol) -> [Character] {
        let folded = token.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: foldingLocale
        )
        var result: [Character] = []
        for character in folded {
            if character.isLetter {
                result.append(contentsOf: character.lowercased())
            } else if let digit = character.wholeNumberValue, digitWords.indices.contains(digit) {
                result.append(contentsOf: digitWords[digit])
            }
        }
        return result
    }

    private static func sounds(_ characters: [Character]) -> [Character] {
        var result: [Character] = []
        var index = 0
        while index < characters.count {
            let character = characters[index]
            let next = index + 1 < characters.count ? characters[index + 1] : nil
            switch character {
            case "t" where next == "h":
                result.append("0")
                index += 2
                continue
            case "p" where next == "h":
                result.append("f")
                index += 2
                continue
            case "g" where next == "h":
                index += 2
                continue
            case "c" where next == "k":
                result.append("k")
                index += 2
                continue
            case "c" where next == "h", "s" where next == "h":
                result.append("x")
                index += 2
                continue
            case "w" where next == "h":
                result.append("w")
                index += 2
                continue
            case "w" where next == "r" && index == 0, "g" where next == "n" && index == 0,
                 "k" where next == "n" && index == 0:
                result.append(next == "r" ? "r" : "n")
                index += 2
                continue
            case "h":
                if let next, isVowel(next, at: 1) { result.append("h") }
            case "c":
                result.append(isSoftFollower(next) ? "s" : "k")
            case "g":
                result.append(isSoftFollower(next) ? "j" : "k")
            case "q":
                result.append("k")
            case "x":
                result.append(contentsOf: ["k", "s"])
            case "z":
                result.append("s")
            case "v":
                result.append("f")
            default:
                result.append(character)
            }
            index += 1
        }
        return result
    }

    private static func isSoftFollower(_ character: Character?) -> Bool {
        guard let character else { return false }
        return character == "e" || character == "i" || character == "y"
    }

    private static func isVowel(_ character: Character, at index: Int) -> Bool {
        vowels.contains(character) || (character == "y" && index > 0)
    }

    private static func droppingInteriorVowels(_ characters: [Character]) -> [Character] {
        characters.enumerated()
            .filter { $0.offset == 0 || !isVowel($0.element, at: $0.offset) }
            .map(\.element)
    }

    private static func collapsingRepeats(_ characters: [Character]) -> [Character] {
        var result: [Character] = []
        for character in characters where result.last != character {
            result.append(character)
        }
        return result
    }

    private static func distance(_ a: String, _ b: String, limit: Int) -> Int {
        if abs(a.count - b.count) > limit { return limit + 1 }
        let source = Array(a)
        let target = Array(b)
        var previous = Array(0...target.count)
        for (i, sourceCharacter) in source.enumerated() {
            var current = [i + 1]
            current.reserveCapacity(target.count + 1)
            for (j, targetCharacter) in target.enumerated() {
                let substitution = previous[j] + (sourceCharacter == targetCharacter ? 0 : 1)
                current.append(min(previous[j + 1] + 1, current[j] + 1, substitution))
            }
            if current.min()! > limit { return limit + 1 }
            previous = current
        }
        return previous[target.count]
    }
}
