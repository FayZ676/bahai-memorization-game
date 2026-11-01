import Foundation

struct ConformerTracker {
    struct Credit {
        let index: Int
        let placement: ConformerAligner.Placement
        let creditedAt: Double
    }

    struct Update {
        var credits: [Credit] = []
        var flashed: Int?
    }

    static let sampleRate = 16_000
    static let windowSamples = 96_000
    static let hopSamples = 4_000
    static let lookaheadSamples = 4_000
    static let samplesPerFrame = 640
    static let frameSeconds = 0.04
    static let keptFrames = 2 * sampleRate / samplesPerFrame
    static let guardSeconds = 0.1
    static let threshold = -7.67
    static let evidence = 7.0
    static let speechFramesForFlash = 3
    static let speechMargin = 2
    static let pauseSeconds = 0.6

    let aligner: ConformerAligner
    let quietSeconds: Double
    var hidden: Set<Int>
    private(set) var frames: ConformerFrames
    private(set) var credits: [Int: Credit] = [:]
    private var flashedAt: [Int: Double] = [:]
    private var latest: ConformerAligner.Alignment?

    init(words: [String], tokenizer: ConformerTokenizer, classes: Int, quietSeconds: Double = 2) {
        aligner = ConformerAligner(words: words, tokenizer: tokenizer, frameSeconds: Self.frameSeconds)
        frames = ConformerFrames(classes: classes, blank: tokenizer.blank)
        self.quietSeconds = quietSeconds
        hidden = Set(aligner.recitable)
    }

    static func windowStart(endingAt end: Int) -> Int {
        max(0, end - windowSamples) / samplesPerFrame * samplesPerFrame
    }

    static func totalFrames(samples: Int) -> Int {
        let melFrames = samples / 160
        let halved = melFrames > 0 ? (melFrames - 1) / 2 + 1 : 0
        return halved > 0 ? (halved - 1) / 2 + 1 : 0
    }

    mutating func absorb(window: UnsafeBufferPointer<Float>, start: Int, end: Int, ready: Int) {
        let first = start / Self.samplesPerFrame
        let windowFrames = window.count / frames.classes
        let refreshFrom = start == 0 ? first : first + Self.keptFrames
        guard refreshFrom < min(ready, first + windowFrames) else { return }
        for index in refreshFrom..<min(ready, first + windowFrames) {
            let offset = (index - first) * frames.classes
            frames.write(UnsafeBufferPointer(rebasing: window[offset..<(offset + frames.classes)]), at: index)
        }
    }

    mutating func step(ready: Int, now: Double, done: Bool) -> Update {
        var update = Update(credits: commit(ready: ready, now: now, done: done))
        guard !done, let owed = owedWord(), heardThenQuiet(after: owed, ready: ready) else { return update }
        flashedAt[order[owed]] = Double(ready) * Self.frameSeconds
        update.flashed = order[owed]
        return update
    }

    mutating func commit(ready: Int, now: Double, done: Bool) -> [Credit] {
        guard ready > 0, frames.count >= ready else { return [] }
        let limit = Double(ready) * Self.frameSeconds - (done ? 0 : Self.guardSeconds)
        let alignment = aligner.align(frames, through: ready, final: done)
        latest = alignment
        let lastCreditEnd = credits.values.map(\.placement.end).max() ?? 0
        let freshAudioFrom = done ? lastCreditEnd - Self.frameSeconds / 2 : -Double.infinity
        var fresh: [Credit] = []
        for (position, index) in aligner.recitable.enumerated() where credits[index] == nil {
            guard let placement = alignment.placements[index] ?? nil,
                  placement.end <= limit,
                  placement.worst >= Self.threshold,
                  heardSpeech(in: placement),
                  placement.start >= freshAudioFrom,
                  !overlapsCredited(placement) else { continue }
            if !done, !confirmedByPause(position, placement, after: lastCreditEnd, ready: ready) {
                let without = aligner.align(frames, through: ready, final: false, forbidding: position)
                guard alignment.score - without.score >= Self.evidence else { continue }
            }
            let credit = Credit(index: index, placement: placement, creditedAt: now)
            credits[index] = credit
            fresh.append(credit)
        }
        return fresh
    }

    private var order: [Int] { aligner.recitable }

    private func heardSpeech(in placement: ConformerAligner.Placement) -> Bool {
        let first = max(0, Int((placement.start / Self.frameSeconds).rounded(.down)) - Self.speechMargin)
        let last = min(frames.count - 1, Int((placement.end / Self.frameSeconds).rounded(.up)) + Self.speechMargin)
        guard first <= last else { return false }
        return (first...last).contains { frames.speech[$0] }
    }

    private func confirmedByPause(_ position: Int, _ placement: ConformerAligner.Placement, after lastCreditEnd: Double, ready: Int) -> Bool {
        position > 0
            && credits[order[position - 1]] != nil
            && placement.start >= lastCreditEnd
            && quietAfter(placement, ready: ready)
    }

    private func quietAfter(_ placement: ConformerAligner.Placement, ready: Int) -> Bool {
        let first = Int((placement.end / Self.frameSeconds).rounded(.up)) + Self.speechMargin
        let heardThrough = Double(min(ready, frames.count)) * Self.frameSeconds
        guard heardThrough - placement.end >= Self.pauseSeconds, first < min(ready, frames.count) else { return false }
        return !(first..<min(ready, frames.count)).contains { frames.speech[$0] }
    }

    private func overlapsCredited(_ placement: ConformerAligner.Placement) -> Bool {
        credits.values.contains { min(placement.end, $0.placement.end) - max(placement.start, $0.placement.start) > Self.frameSeconds / 2 }
    }

    private func owedWord() -> Int? {
        order.firstIndex { hidden.contains($0) && credits[$0] == nil }
    }

    private func heardThenQuiet(after position: Int, ready: Int) -> Bool {
        guard var anchor = reachedEnd(before: position) else { return false }
        anchor = max(anchor, flashedAt[order[position]] ?? 0)
        var spoken = 0
        var lastSpoken = 0.0
        var frame = Int((anchor / Self.frameSeconds).rounded(.up))
        while frame < min(ready, frames.count) {
            if frames.speech[frame] {
                spoken += 1
                lastSpoken = Double(frame + 1) * Self.frameSeconds
            }
            frame += 1
        }
        let heardThrough = Double(ready) * Self.frameSeconds
        return spoken >= Self.speechFramesForFlash && heardThrough - lastSpoken >= quietSeconds
    }

    private func reachedEnd(before position: Int) -> Double? {
        for previous in stride(from: position - 1, through: 0, by: -1) {
            let index = order[previous]
            if let credit = credits[index] { return credit.placement.end }
            if hidden.contains(index) { return nil }
            guard let placement = latest?.placements[index] ?? nil, placement.worst >= Self.threshold else { return nil }
            return placement.end
        }
        return 0
    }
}
