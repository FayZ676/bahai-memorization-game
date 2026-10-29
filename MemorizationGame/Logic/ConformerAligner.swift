import Foundation

struct ConformerFrames {
    let classes: Int
    let blank: Int
    private(set) var values: [Float] = []
    private(set) var peaks: [Float] = []
    private(set) var speech: [Bool] = []

    init(classes: Int, blank: Int) {
        self.classes = classes
        self.blank = blank
    }

    var count: Int { peaks.count }

    mutating func write(_ row: UnsafeBufferPointer<Float>, at index: Int) {
        if index >= count {
            values.append(contentsOf: repeatElement(0, count: (index + 1 - count) * classes))
            speech.append(contentsOf: repeatElement(false, count: index + 1 - count))
            peaks.append(contentsOf: repeatElement(0, count: index + 1 - count))
        }
        var peak = -Float.infinity
        values.withUnsafeMutableBufferPointer { values in
            let offset = index * classes
            for column in 0..<classes {
                let value = row[column]
                values[offset + column] = value
                if value > peak { peak = value }
            }
        }
        peaks[index] = peak
        speech[index] = row[blank] < peak
    }
}

struct ConformerAligner {
    struct Placement {
        let gop: Double
        let worst: Double
        let start: Double
        let end: Double
    }

    struct Alignment {
        let score: Double
        let placements: [Int: Placement?]
    }

    private static let impossible = -1e30

    let recitable: [Int]
    private let pieceCounts: [Int]
    private let token: [Int32]
    private let wordOf: [Int32]
    private let first: [Int]
    private let allowsJump: [Bool]
    private let isFirst: [Bool]
    private let isEntry: [Bool]
    private let closingPiece: [Int32]
    private let closingBlank: [Int32]
    private let blank: Int
    private let garbage = 2.0
    private let skip = 20.0
    private let restart = 10.0
    private let flatStart = 20.0
    private let frameSeconds: Double

    init(words: [String], tokenizer: ConformerTokenizer, frameSeconds: Double) {
        let tokenized = words.map(tokenizer.tokenize)
        recitable = words.indices.filter { !tokenized[$0].isEmpty }
        pieceCounts = recitable.map { tokenized[$0].count }
        blank = tokenizer.blank
        self.frameSeconds = frameSeconds
        var token: [Int32] = []
        var wordOf: [Int32] = []
        var first: [Int] = []
        var allowsJump: [Bool] = []
        var closingPiece: [Int32] = []
        var closingBlank: [Int32] = []
        for (position, index) in recitable.enumerated() {
            let pieces = tokenized[index]
            first.append(token.count)
            for state in 0..<(2 * pieces.count + 1) {
                let isPiece = state % 2 == 1
                token.append(isPiece ? Int32(pieces[state / 2]) : -1)
                wordOf.append(Int32(position))
                allowsJump.append(isPiece && state >= 3 && pieces[state / 2] != pieces[state / 2 - 1])
            }
            closingPiece.append(Int32(token.count - 2))
            closingBlank.append(Int32(token.count - 1))
        }
        var isFirst = [Bool](repeating: false, count: token.count)
        var isEntry = [Bool](repeating: false, count: token.count)
        for start in first {
            isFirst[start] = true
            isEntry[start] = true
            isEntry[start + 1] = true
        }
        self.token = token
        self.wordOf = wordOf
        self.first = first
        self.allowsJump = allowsJump
        self.isFirst = isFirst
        self.isEntry = isEntry
        self.closingPiece = closingPiece
        self.closingBlank = closingBlank
    }

    func align(_ frames: ConformerFrames, through frameCount: Int, final: Bool, forbidding forbidden: Int? = nil) -> Alignment {
        let T = frameCount
        let W = recitable.count
        guard T > 0, W > 0 else { return Alignment(score: Self.impossible, placements: [:]) }
        return frames.values.withUnsafeBufferPointer { values in
            frames.peaks.withUnsafeBufferPointer { peaks in
                token.withUnsafeBufferPointer { token in
                    wordOf.withUnsafeBufferPointer { wordOf in
                        allowsJump.withUnsafeBufferPointer { allowsJump in
                            isFirst.withUnsafeBufferPointer { isFirst in
                                isEntry.withUnsafeBufferPointer { isEntry in
                                    closingPiece.withUnsafeBufferPointer { closingPiece in
                                        closingBlank.withUnsafeBufferPointer { closingBlank in
                                            align(
                                                Lattice(
                                                    values: values.baseAddress!, peaks: peaks.baseAddress!,
                                                    token: token.baseAddress!, wordOf: wordOf.baseAddress!,
                                                    allowsJump: allowsJump.baseAddress!, isFirst: isFirst.baseAddress!,
                                                    isEntry: isEntry.baseAddress!, closingPiece: closingPiece.baseAddress!,
                                                    closingBlank: closingBlank.baseAddress!,
                                                    classes: frames.classes, blank: blank,
                                                    forbidden: Int32(forbidden ?? -1)
                                                ),
                                                T: T, final: final
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private struct Lattice {
        let values: UnsafePointer<Float>
        let peaks: UnsafePointer<Float>
        let token: UnsafePointer<Int32>
        let wordOf: UnsafePointer<Int32>
        let allowsJump: UnsafePointer<Bool>
        let isFirst: UnsafePointer<Bool>
        let isEntry: UnsafePointer<Bool>
        let closingPiece: UnsafePointer<Int32>
        let closingBlank: UnsafePointer<Int32>
        let classes: Int
        let blank: Int
        let forbidden: Int32

        func emit(_ t: Int, _ s: Int) -> Double {
            if wordOf[s] == forbidden { return ConformerAligner.impossible }
            let column = token[s] < 0 ? blank : Int(token[s])
            return Double(values[t * classes + column])
        }

        func peak(_ t: Int) -> Double { Double(peaks[t]) }
    }

    private func align(_ lattice: Lattice, T: Int, final: Bool) -> Alignment {
        let W = recitable.count
        let N = token.count
        let impossible = Self.impossible
        let values = lattice.values
        let classes = lattice.classes
        let blankColumn = lattice.blank
        let token = lattice.token
        let wordOf = lattice.wordOf
        let allowsJump = lattice.allowsJump
        let isFirst = lattice.isFirst
        let isEntry = lattice.isEntry
        let closingPiece = lattice.closingPiece
        let closingBlank = lattice.closingBlank
        let forbidden = lattice.forbidden

        let delta = UnsafeMutablePointer<Double>.allocate(capacity: N)
        let next = UnsafeMutablePointer<Double>.allocate(capacity: N)
        let G = UnsafeMutablePointer<Double>.allocate(capacity: W + 1)
        let X = UnsafeMutablePointer<Double>.allocate(capacity: W)
        let A = UnsafeMutablePointer<Double>.allocate(capacity: W + 1)
        let R = UnsafeMutablePointer<Double>.allocate(capacity: W)
        let back = UnsafeMutablePointer<Double>.allocate(capacity: W)
        let backSource = UnsafeMutablePointer<Int32>.allocate(capacity: W)
        let code = UnsafeMutablePointer<Int8>.allocate(capacity: T * N)
        let entrySource = UnsafeMutablePointer<Int32>.allocate(capacity: T * W)
        let aFrom = UnsafeMutablePointer<Bool>.allocate(capacity: T * (W + 1))
        let xState = UnsafeMutablePointer<Int32>.allocate(capacity: T * W)
        let gFromX = UnsafeMutablePointer<Bool>.allocate(capacity: T * (W + 1))
        defer {
            for pointer in [delta, next, G, X, A, R, back] as [UnsafeMutablePointer<Double>] { pointer.deallocate() }
            backSource.deallocate()
            code.deallocate()
            entrySource.deallocate()
            aFrom.deallocate()
            xState.deallocate()
            gFromX.deallocate()
        }
        delta.initialize(repeating: impossible, count: N)
        next.initialize(repeating: impossible, count: N)
        G.initialize(repeating: impossible, count: W + 1)
        X.initialize(repeating: impossible, count: W)
        A.initialize(repeating: impossible, count: W + 1)
        R.initialize(repeating: impossible, count: W)
        back.initialize(repeating: impossible, count: W)
        backSource.initialize(repeating: 0, count: W)

        var current = delta
        var upcoming = next
        var t = 0
        while t < T {
            let gemit = lattice.peak(t) - garbage
            let source = entrySource + t * W
            let xs = xState + t * W
            let af = aFrom + t * (W + 1)
            if t == 0 {
                var w = 0
                while w < W {
                    X[w] = impossible
                    xs[w] = closingPiece[w]
                    R[w] = w == 0 ? 0 : -flatStart
                    source[w] = 0
                    w += 1
                }
                var j = 0
                while j <= W {
                    A[j] = j == 0 ? 0 : impossible
                    af[j] = true
                    j += 1
                }
            } else {
                var w = 0
                while w < W {
                    let pieceScore = current[Int(closingPiece[w])]
                    let blankScore = current[Int(closingBlank[w])]
                    if blankScore > pieceScore {
                        X[w] = blankScore
                        xs[w] = closingBlank[w]
                    } else {
                        X[w] = pieceScore
                        xs[w] = closingPiece[w]
                    }
                    w += 1
                }
                A[0] = G[0]
                af[0] = true
                var j = 1
                while j <= W {
                    A[j] = X[j - 1] > G[j] ? X[j - 1] : G[j]
                    af[j] = G[j] >= X[j - 1]
                    j += 1
                }
                var run = impossible
                var runSource: Int32 = 0
                j = 0
                while j < W {
                    if A[j] >= run - skip {
                        run = A[j]
                        runSource = Int32(j)
                    } else {
                        run -= skip
                    }
                    R[j] = run
                    source[j] = runSource
                    j += 1
                }
                j = W - 1
                while j >= 0 {
                    let later = j + 1 < W ? back[j + 1] : impossible
                    if A[j + 1] >= later {
                        back[j] = A[j + 1]
                        backSource[j] = Int32(j + 1)
                    } else {
                        back[j] = later
                        backSource[j] = j + 1 < W ? backSource[j + 1] : Int32(W)
                    }
                    j -= 1
                }
                j = 0
                while j < W {
                    let jumped = back[j] - restart
                    if jumped > R[j] {
                        R[j] = jumped
                        source[j] = backSource[j]
                    }
                    j += 1
                }
            }

            let row = values + t * classes
            let blankValue = Double(row[blankColumn])
            let choices = code + t * N
            var s = 0
            while s < N {
                var best = current[s]
                var choice: Int8 = 0
                if s >= 1, !isFirst[s], current[s - 1] > best {
                    best = current[s - 1]
                    choice = 1
                }
                if s >= 2, allowsJump[s], current[s - 2] > best {
                    best = current[s - 2]
                    choice = 2
                }
                if isEntry[s] {
                    let entry = R[Int(wordOf[s])]
                    if entry > best {
                        best = entry
                        choice = 3
                    }
                }
                let piece = token[s]
                let emitted = wordOf[s] == forbidden ? impossible : (piece < 0 ? blankValue : Double(row[Int(piece)]))
                upcoming[s] = best + emitted
                choices[s] = choice
                s += 1
            }

            let fromX = gFromX + t * (W + 1)
            var j = W
            while j >= 0 {
                let stay = G[j]
                let fromWord = j == 0 ? (t == 0 ? 0 : impossible) : X[j - 1]
                G[j] = gemit + (fromWord > stay ? fromWord : stay)
                fromX[j] = fromWord > stay
                j -= 1
            }
            swap(&current, &upcoming)
            t += 1
        }

        var lastChoice = [Int](repeating: 0, count: W)
        for w in 0..<W {
            let pieceScore = current[Int(closingPiece[w])]
            let blankScore = current[Int(closingBlank[w])]
            X[w] = max(pieceScore, blankScore)
            lastChoice[w] = Int(blankScore > pieceScore ? closingBlank[w] : closingPiece[w])
        }
        var end = 0
        var score = -Double.infinity
        for j in 0...W {
            let reached = j == 0 ? G[0] : max(X[j - 1], G[j])
            let tail = reached - (final ? skip : 0) * Double(W - j)
            if tail > score {
                score = tail
                end = j
            }
        }

        var path: [[(t: Int, s: Int)]] = Array(repeating: [], count: W)
        var inGarbage = end == 0 || G[end] >= X[end - 1]
        var state = inGarbage ? end : lastChoice[end - 1]
        t = T - 1
        while t >= 0 {
            if inGarbage {
                if t == 0 { break }
                if gFromX[t * (W + 1) + state] {
                    if state > 0 {
                        inGarbage = false
                        state = Int(xState[t * W + state - 1])
                    } else {
                        state = 0
                    }
                }
                t -= 1
                continue
            }
            path[Int(wordOf[state])].append((t, state))
            switch code[t * N + state] {
            case 0:
                break
            case 1:
                state -= 1
            case 2:
                state -= 2
            default:
                let entry = Int(entrySource[t * W + Int(wordOf[state])])
                if t == 0 { t = -1; continue }
                if aFrom[t * (W + 1) + entry] || entry == 0 {
                    inGarbage = true
                    state = entry
                } else {
                    state = Int(xState[t * W + entry - 1])
                }
            }
            t -= 1
        }

        var placements: [Int: Placement?] = [:]
        for (position, index) in recitable.enumerated() {
            let assigned = path[position].reversed()
            var segments: [[(t: Int, s: Int)]] = []
            for step in assigned {
                if let previous = segments.last?.last, step.t == previous.t + 1 {
                    segments[segments.count - 1].append(step)
                } else {
                    segments.append([step])
                }
            }
            let expected = Set((0..<pieceCounts[position]).map { first[position] + 1 + 2 * $0 })
            var best: Placement?
            for segment in segments {
                let pieces = segment.filter { token[$0.s] >= 0 }
                guard let low = pieces.first?.t, let high = pieces.last?.t else { continue }
                let span = segment.filter { $0.t >= low && $0.t <= high }
                let gop = span.map { lattice.emit($0.t, $0.s) - lattice.peak($0.t) }.reduce(0, +) / Double(span.count)
                var perPiece: [Int: [Double]] = [:]
                for step in pieces { perPiece[step.s, default: []].append(lattice.emit(step.t, step.s) - lattice.peak(step.t)) }
                var worst = perPiece.values.map { $0.reduce(0, +) / Double($0.count) }.min() ?? -.infinity
                if Set(perPiece.keys) != expected { worst = -.infinity }
                let candidate = Placement(gop: gop, worst: worst, start: Double(low) * frameSeconds, end: Double(high + 1) * frameSeconds)
                if best == nil || candidate.worst > best!.worst { best = candidate }
            }
            placements[index] = best
        }
        return Alignment(score: score, placements: placements)
    }
}
