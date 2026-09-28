import Foundation

enum RecitationContext {
    static let entryLimit = 100

    static func contextualStrings(for text: String) -> [String] {
        let written = writtenWords(in: text)
        guard !written.isEmpty else { return [] }

        var seen: Set<String> = []
        var result: [String] = []

        func append(_ candidate: String) {
            let trimmed = candidate.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, result.count < entryLimit else { return }
            let key = trimmed.lowercased()
            guard seen.insert(key).inserted else { return }
            result.append(trimmed)
        }

        let uncommon = written.indices.filter { !stopwords.contains(written[$0].text.lowercased()) }

        for index in uncommon {
            append(written[index].text)
        }

        for index in uncommon where needsASCIITwin(written[index].text) {
            append(asciiTwin(written[index].text))
        }

        for index in uncommon {
            let lower = max(0, index - 1)
            let upper = min(written.count - 1, index + 2)
            append(written[lower...upper].map(\.text).joined(separator: " "))
        }

        return result
    }

    private struct WrittenWord {
        let text: String
    }

    private static func writtenWords(in text: String) -> [WrittenWord] {
        let tokens = Reviewable.tokens(in: text)
        var words: [WrittenWord] = []
        var start = 0

        func flush(end: Int) {
            guard end > start else { return }
            let joined = tokens[start..<end].joined()
            let stripped = stripOuterPunctuation(joined)
            if !stripped.isEmpty {
                words.append(WrittenWord(text: stripped))
            }
            start = end
        }

        for index in tokens.indices where index > start && !tokens[index].hasPrefix("-") {
            flush(end: index)
        }
        flush(end: tokens.count)
        return words
    }

    private static func stripOuterPunctuation(_ word: String) -> String {
        let keep: Set<Character> = ["-", "'", "\u{2019}"]
        var characters = Array(word)
        while let first = characters.first, !first.isLetter, !first.isNumber, !keep.contains(first) {
            characters.removeFirst()
        }
        while let last = characters.last, !last.isLetter, !last.isNumber {
            characters.removeLast()
        }
        return String(characters)
    }

    private static func needsASCIITwin(_ word: String) -> Bool {
        word.unicodeScalars.contains { !$0.isASCII } || word.contains("'") || word.contains("\u{2019}")
    }

    private static func asciiTwin(_ word: String) -> String {
        word
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US"))
            .filter { $0 != "'" && $0 != "\u{2019}" }
    }

    private static let stopwords: Set<String> = [
        "a", "about", "after", "all", "am", "an", "and", "any", "are", "as", "at", "be", "because",
        "been", "before", "being", "but", "by", "can", "did", "do", "does", "down", "each", "for",
        "from", "had", "has", "have", "he", "her", "here", "him", "his", "how", "i", "if", "in",
        "into", "is", "it", "its", "just", "may", "me", "more", "most", "my", "no", "nor", "not",
        "now", "of", "off", "on", "once", "one", "only", "or", "other", "our", "out", "over",
        "own", "same", "she", "should", "so", "some", "such", "than", "that", "the", "their",
        "them", "then", "there", "these", "they", "this", "those", "through", "to", "too", "under",
        "until", "up", "very", "was", "we", "were", "what", "when", "where", "which", "while",
        "who", "whom", "why", "will", "with", "would", "you", "your",
    ]
}
