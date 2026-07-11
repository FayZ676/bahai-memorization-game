import Foundation

enum RecitationAligner {
    static func normalize(_ token: some StringProtocol) -> String {
        token
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
            .filter(\.isLetter)
    }

    static func tokensMatch(_ spoken: String, _ reference: String) -> Bool {
        guard spoken != reference else { return true }
        let tolerance: Int
        switch reference.count {
        case ..<4: return false
        case 4...6: tolerance = 1
        default: tolerance = 2
        }
        return levenshtein(spoken, reference, limit: tolerance) <= tolerance
    }

    static func matchedFrontier(reference: [String], transcript: [String]) -> Int? {
        let ref = reference.map(normalize)
        let spoken = transcript.map(normalize).filter { !$0.isEmpty }
        guard !ref.isEmpty, !spoken.isEmpty else { return nil }

        let gap = -1
        var score = [[Int]](repeating: [Int](repeating: 0, count: spoken.count + 1), count: ref.count + 1)
        var matched = [[Bool]](repeating: [Bool](repeating: false, count: spoken.count + 1), count: ref.count + 1)
        for r in 1...ref.count { score[r][0] = r * gap }
        for s in 1...spoken.count { score[0][s] = s * gap }

        for r in 1...ref.count {
            for s in 1...spoken.count {
                let isMatch = tokensMatch(spoken[s - 1], ref[r - 1])
                let diagonal = score[r - 1][s - 1] + (isMatch ? 2 : -1)
                let skipRef = score[r - 1][s] + gap
                let skipSpoken = score[r][s - 1] + gap
                let best = max(diagonal, skipRef, skipSpoken)
                score[r][s] = best
                matched[r][s] = isMatch && best == diagonal
            }
        }

        var r = ref.count
        var s = spoken.count
        while r > 0 && s > 0 {
            if matched[r][s] {
                return r - 1
            }
            if score[r][s] == score[r - 1][s - 1] + (matched[r][s] ? 2 : -1) {
                r -= 1
                s -= 1
            } else if score[r][s] == score[r - 1][s] + gap {
                r -= 1
            } else {
                s -= 1
            }
        }
        return nil
    }

    private static func levenshtein(_ a: String, _ b: String, limit: Int) -> Int {
        if abs(a.count - b.count) > limit { return limit + 1 }
        let aChars = Array(a)
        let bChars = Array(b)
        var previous = Array(0...bChars.count)
        for (i, aChar) in aChars.enumerated() {
            var current = [i + 1]
            current.reserveCapacity(bChars.count + 1)
            for (j, bChar) in bChars.enumerated() {
                let substitution = previous[j] + (aChar == bChar ? 0 : 1)
                current.append(min(previous[j + 1] + 1, current[j] + 1, substitution))
            }
            if current.min()! > limit { return limit + 1 }
            previous = current
        }
        return previous[bChars.count]
    }
}
