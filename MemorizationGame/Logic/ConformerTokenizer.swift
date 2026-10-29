import Foundation

struct ConformerVocabulary: Decodable {
    let blank: Int
    let pieces: [String]
    let scores: [Float]
}

struct ConformerTokenizer {
    let blank: Int
    private let pieceIDs: [String: Int]
    private let scores: [Float]
    private let longestPiece: Int
    private let unknownID = 0
    private let unknownScore: Float

    init(_ vocabulary: ConformerVocabulary) {
        blank = vocabulary.blank
        var pieceIDs: [String: Int] = [:]
        for (id, piece) in vocabulary.pieces.enumerated() where id != 0 && !piece.hasPrefix("<") {
            pieceIDs[piece] = id
        }
        self.pieceIDs = pieceIDs
        scores = vocabulary.scores
        longestPiece = vocabulary.pieces.map { $0.unicodeScalars.count }.max() ?? 1
        unknownScore = (vocabulary.scores.min() ?? 0) - 10
    }

    func tokenize(_ word: String) -> [Int] {
        let cleaned = String(word.lowercased().filter { $0.isLetter || $0 == "'" })
        guard !cleaned.isEmpty else { return [] }
        let normalized = cleaned.precomposedStringWithCompatibilityMapping
            .folding(options: .caseInsensitive, locale: nil)
        let scalars = Array(("▁" + normalized).unicodeScalars)
        let count = scalars.count
        var best = [Float](repeating: -.infinity, count: count + 1)
        var piece = [Int](repeating: -1, count: count + 1)
        var from = [Int](repeating: 0, count: count + 1)
        best[0] = 0
        for start in 0..<count where best[start] > -.infinity {
            var coveredSingle = false
            var text = String.UnicodeScalarView()
            for end in (start + 1)...min(count, start + longestPiece) {
                text.append(scalars[end - 1])
                guard let id = pieceIDs[String(text)] else { continue }
                if end == start + 1 { coveredSingle = true }
                let score = best[start] + scores[id]
                if score > best[end] {
                    best[end] = score
                    piece[end] = id
                    from[end] = start
                }
            }
            if !coveredSingle {
                let score = best[start] + unknownScore
                if score > best[start + 1] {
                    best[start + 1] = score
                    piece[start + 1] = unknownID
                    from[start + 1] = start
                }
            }
        }
        var ids: [Int] = []
        var position = count
        while position > 0 {
            ids.append(piece[position])
            position = from[position]
        }
        var merged: [Int] = []
        for id in ids.reversed() where !(id == unknownID && merged.last == unknownID) {
            merged.append(id)
        }
        return merged
    }
}
