import Foundation

struct WordLayout {
    let words: [Substring]
    let paragraphs: [Range<Int>]
}

enum WordLayoutStore {
    private static let capacity = 96
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: [String: WordLayout] = [:]
    nonisolated(unsafe) private static var admitted: [String] = []

    static func layout(for text: String) -> WordLayout {
        lock.lock()
        if let hit = cache[text] {
            lock.unlock()
            return hit
        }
        lock.unlock()

        let built = build(text)

        lock.lock()
        if cache.updateValue(built, forKey: text) == nil {
            admitted.append(text)
            if admitted.count > capacity {
                cache.removeValue(forKey: admitted.removeFirst())
            }
        }
        lock.unlock()
        return built
    }

    static func tokenize(_ text: Substring) -> [Substring] {
        text
            .split(whereSeparator: { $0 == " " || $0 == "\n" })
            .flatMap(splitInternalHyphens)
    }

    private static func build(_ text: String) -> WordLayout {
        let words = tokenize(text[...])
        var ranges: [Range<Int>] = []
        var start = 0
        for paragraph in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let count = tokenize(paragraph).count
            guard count > 0 else { continue }
            ranges.append(start..<(start + count))
            start += count
        }
        return WordLayout(words: words, paragraphs: ranges.isEmpty ? [0..<words.count] : ranges)
    }

    private static func splitInternalHyphens(_ word: Substring) -> [Substring] {
        var pieces: [Substring] = []
        var pieceStart = word.startIndex
        var searchStart = word.startIndex
        while let hyphenIndex = word[searchStart...].firstIndex(of: "-") {
            let afterHyphen = word.index(after: hyphenIndex)
            if hyphenIndex > pieceStart, afterHyphen < word.endIndex {
                pieces.append(word[pieceStart..<hyphenIndex])
                pieceStart = hyphenIndex
            }
            searchStart = afterHyphen
        }
        pieces.append(word[pieceStart...])
        return pieces
    }
}
