import Foundation

enum HiddenWordAlignment {
    static func remap(oldWords: [String], hidden: Set<Int>, newWords: [String]) -> Set<Int> {
        guard oldWords != newWords else { return hidden }
        guard !oldWords.isEmpty, !newWords.isEmpty, !hidden.isEmpty else { return [] }

        let old = oldWords.map { $0.lowercased() }
        let new = newWords.map { $0.lowercased() }

        var lengths = [[Int]](
            repeating: [Int](repeating: 0, count: new.count + 1),
            count: old.count + 1
        )
        for i in stride(from: old.count - 1, through: 0, by: -1) {
            for j in stride(from: new.count - 1, through: 0, by: -1) {
                lengths[i][j] = old[i] == new[j]
                    ? lengths[i + 1][j + 1] + 1
                    : max(lengths[i + 1][j], lengths[i][j + 1])
            }
        }

        var remapped: Set<Int> = []
        var i = 0
        var j = 0
        while i < old.count && j < new.count {
            if old[i] == new[j] {
                if hidden.contains(i) { remapped.insert(j) }
                i += 1
                j += 1
            } else if lengths[i + 1][j] >= lengths[i][j + 1] {
                i += 1
            } else {
                j += 1
            }
        }
        return remapped
    }
}
