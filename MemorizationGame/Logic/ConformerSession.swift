import Foundation

struct ConformerSession {
    struct Window {
        let start: Int
        let end: Int
        let ready: Int
        let done: Bool
    }

    struct Update {
        var credits: [Int] = []
        var flashed: Int?
        var hops = 0

        mutating func merge(_ other: Update) {
            credits += other.credits
            if let flashed = other.flashed { self.flashed = flashed }
            hops += other.hops
        }
    }

    static let wordSpan = 64
    static let advanceAfter = 24
    static let keepBack = 8
    static let longestAudio = 45 * ConformerTracker.sampleRate

    private let words: [String]
    private let tokenizer: ConformerTokenizer
    private let classes: Int
    private let span: Int
    private(set) var hidden: Set<Int>
    private(set) var anchorWord = 0
    private(set) var anchorSample = 0
    private var processedEnd = 0
    private var tracker: ConformerTracker
    private var audio: [Float] = []
    private var audioStart = 0
    private var nextHop = ConformerTracker.hopSamples

    private var heard: Int { audioStart + audio.count }

    init(
        words: [String],
        hidden: Set<Int>,
        start: Int = 0,
        tokenizer: ConformerTokenizer,
        classes: Int,
        span: Int = wordSpan
    ) {
        self.words = words
        self.hidden = hidden
        self.tokenizer = tokenizer
        self.classes = classes
        self.span = span
        anchorWord = min(max(start, 0), words.count)
        tracker = ConformerTracker(words: [], tokenizer: tokenizer, classes: classes)
        tracker = makeTracker()
    }

    mutating func setHidden(_ hidden: Set<Int>) {
        self.hidden = hidden
        tracker.hidden = localHidden
    }

    mutating func append(_ samples: [Float], predict: (UnsafeBufferPointer<Float>) -> [Float]?) -> Update {
        audio += samples
        var update = Update()
        while heard >= nextHop {
            let end = nextHop
            nextHop += ConformerTracker.hopSamples
            update.merge(listen(through: end, done: false, predict: predict))
        }
        return update
    }

    mutating func finish(predict: (UnsafeBufferPointer<Float>) -> [Float]?) -> Update {
        guard heard > 0 else { return Update() }
        return listen(through: heard + ConformerTracker.lookaheadSamples, done: true, predict: predict)
    }

    private func windows(endingAt end: Int, done: Bool) -> [Window] {
        let localEnd = end - anchorSample
        var ends = Array(stride(from: processedEnd + ConformerTracker.hopSamples, to: localEnd, by: ConformerTracker.hopSamples))
        ends.append(localEnd)
        return ends.enumerated().map { number, local in
            let last = number == ends.count - 1
            let ready = last && done
                ? ConformerTracker.totalFrames(samples: heard - anchorSample)
                : max(0, (local - ConformerTracker.lookaheadSamples) / ConformerTracker.samplesPerFrame)
            return Window(
                start: anchorSample + ConformerTracker.windowStart(endingAt: local),
                end: anchorSample + local,
                ready: ready,
                done: last && done
            )
        }
    }

    private mutating func listen(
        through end: Int,
        done: Bool,
        predict: (UnsafeBufferPointer<Float>) -> [Float]?
    ) -> Update {
        var update = Update(hops: 1)
        var chunk = [Float](repeating: 0, count: ConformerTracker.windowSamples)
        for window in windows(endingAt: end, done: done) {
            let available = max(0, min(window.end, heard) - window.start)
            let first = window.start - audioStart
            for offset in chunk.indices {
                chunk[offset] = offset < available ? audio[first + offset] : 0
            }
            guard let rows = chunk.withUnsafeBufferPointer(predict) else { continue }
            rows.withUnsafeBufferPointer { absorb($0, for: window) }
            let step = step(window, now: Double(window.end) / Double(ConformerTracker.sampleRate))
            update.credits += step.credits
            if let flashed = step.flashed { update.flashed = flashed }
        }
        forgetAudio(before: anchorSample)
        return update
    }

    private mutating func forgetAudio(before sample: Int) {
        guard sample > audioStart else { return }
        audio.removeFirst(min(sample - audioStart, audio.count))
        audioStart = sample
    }

    private mutating func absorb(_ rows: UnsafeBufferPointer<Float>, for window: Window) {
        tracker.absorb(window: rows, start: window.start - anchorSample, end: window.end - anchorSample, ready: window.ready)
    }

    private mutating func step(_ window: Window, now: Double) -> Update {
        let local = tracker.step(ready: window.ready, now: now, done: window.done)
        processedEnd = window.end - anchorSample
        let update = Update(
            credits: local.credits.map { $0.index + anchorWord },
            flashed: local.flashed.map { $0 + anchorWord }
        )
        if !window.done { advance(through: window.end) }
        return update
    }

    private var localHidden: Set<Int> {
        let upper = min(anchorWord + span, words.count)
        return Set(hidden.filter { $0 >= anchorWord && $0 < upper }.map { $0 - anchorWord })
    }

    private func makeTracker() -> ConformerTracker {
        let upper = min(anchorWord + span, words.count)
        var tracker = ConformerTracker(
            words: Array(words[anchorWord..<upper]),
            tokenizer: tokenizer,
            classes: classes
        )
        tracker.hidden = localHidden
        return tracker
    }

    private mutating func advance(through end: Int) {
        let credits = tracker.credits
        let crowded = end - anchorSample > Self.longestAudio
        guard let last = credits.keys.max() else {
            if crowded { restart(word: anchorWord, sample: end - ConformerTracker.windowSamples) }
            return
        }
        var cut = last + 1 - Self.keepBack
        while cut > 0, credits[cut - 1] == nil { cut -= 1 }
        if crowded, cut == 0 { cut = last + 1 }
        guard cut >= Self.advanceAfter || (crowded && cut > 0), let anchor = credits[cut - 1] else { return }
        let sample = anchorSample + Int(anchor.placement.end * Double(ConformerTracker.sampleRate))
        restart(word: anchorWord + cut, sample: max(sample, end - ConformerTracker.windowSamples))
    }

    private mutating func restart(word: Int, sample: Int) {
        anchorWord = word
        anchorSample = max(sample, anchorSample)
        processedEnd = 0
        tracker = makeTracker()
    }
}
