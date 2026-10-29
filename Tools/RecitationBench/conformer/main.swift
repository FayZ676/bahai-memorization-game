import AVFoundation
import CoreML
import Foundation

struct Take: Decodable {
    let words: [String]
    let startIndex: Int?
}

struct Report: Decodable {
    let windows: Int
    let frames: Int
    let classes: Int
    let starts: [Int]
}

func loadVocabulary(_ path: String) throws -> ConformerTokenizer {
    ConformerTokenizer(try JSONDecoder().decode(ConformerVocabulary.self, from: Data(contentsOf: URL(filePath: path))))
}

func checkTokenizer(vocabulary: String, reference: String) throws {
    let tokenizer = try loadVocabulary(vocabulary)
    let expected = try JSONDecoder().decode([String: [Int]].self, from: Data(contentsOf: URL(filePath: reference)))
    var mismatches = 0
    for (word, ids) in expected.sorted(by: { $0.key < $1.key }) where tokenizer.tokenize(word) != ids {
        mismatches += 1
        if mismatches <= 15 { print("mismatch \(word): swift \(tokenizer.tokenize(word)) python \(ids)") }
    }
    print("tokenizer: \(expected.count - mismatches)/\(expected.count) words match")
}

func replay(takes: String, windows: String, model: String, vocabulary: String, out: String, quiet: Double, hiding: String) throws {
    let tokenizer = try loadVocabulary(vocabulary)
    let fileManager = FileManager.default
    let stems = try fileManager.contentsOfDirectory(atPath: takes)
        .filter { $0.hasPrefix("bench-") && $0.hasSuffix(".wav") }
        .map { String($0.dropLast(4)) }
        .sorted()
    var output: [String: Any] = [:]
    for stem in stems {
        let take = try JSONDecoder().decode(Take.self, from: Data(contentsOf: URL(filePath: "\(takes)/\(stem).json")))
        let samples = Int(try AVAudioFile(forReading: URL(filePath: "\(takes)/\(stem).wav")).length)
        let report = try JSONDecoder().decode(Report.self, from: Data(contentsOf: URL(filePath: "\(windows)/\(stem).\(model).json")))
        let raw = try Data(contentsOf: URL(filePath: "\(windows)/\(stem).\(model).f16"))
        let halves = raw.withUnsafeBytes { Array($0.bindMemory(to: Float16.self)) }
        let values = halves.map(Float.init)
        let total = ConformerTracker.totalFrames(samples: samples)
        var tracker = ConformerTracker(words: take.words, tokenizer: tokenizer, classes: report.classes, quietSeconds: quiet)
        if hiding == "scattered" {
            tracker.hidden = Set(tracker.aligner.recitable.enumerated().filter { $0.offset % 3 == 2 }.map(\.element))
        }
        var misses: [[String: Any]] = []
        let clock = ContinuousClock.now
        var heard = 0
        for (number, start) in report.starts.enumerated() {
            heard += ConformerTracker.hopSamples
            let end = min(heard, samples + ConformerTracker.lookaheadSamples)
            let done = heard >= samples + ConformerTracker.lookaheadSamples
            precondition(start == ConformerTracker.windowStart(endingAt: end))
            let ready = done ? total : min(total, (end - ConformerTracker.lookaheadSamples) / ConformerTracker.samplesPerFrame)
            let size = report.frames * report.classes
            values.withUnsafeBufferPointer { all in
                tracker.absorb(window: UnsafeBufferPointer(rebasing: all[(number * size)..<((number + 1) * size)]), start: start, end: end, ready: ready)
            }
            let update = tracker.step(ready: ready, now: Double(end) / Double(ConformerTracker.sampleRate), done: done)
            if let flashed = update.flashed {
                misses.append(["index": flashed, "movedOn": false, "at": Double(ready) * ConformerTracker.frameSeconds])
            }
        }
        var words: [String: Any] = [:]
        for index in tracker.aligner.recitable {
            if let credit = tracker.credits[index] {
                words[String(index)] = [
                    "gop": credit.placement.gop, "worst": credit.placement.worst,
                    "start": credit.placement.start, "end": credit.placement.end, "credited_at": credit.creditedAt,
                ]
            } else {
                words[String(index)] = NSNull()
            }
        }
        output[stem] = ["words": words, "heard": "", "hidden": tracker.hidden.sorted(), "misses": misses]
        let elapsed = ContinuousClock.now - clock
        print("\(stem) credited \(tracker.credits.count)/\(tracker.aligner.recitable.count) in \(elapsed)")
    }
    try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]).write(to: URL(filePath: out))
}

func live(takes: String, model modelPath: String, vocabulary: String, out: String, span: Int) throws {
    let tokenizer = try loadVocabulary(vocabulary)
    let configuration = MLModelConfiguration()
    configuration.computeUnits = .all
    let model = try MLModel(contentsOf: URL(filePath: modelPath), configuration: configuration)
    let input = try MLMultiArray(shape: [1, NSNumber(value: ConformerTracker.windowSamples)], dataType: .float32)
    let predict: (UnsafeBufferPointer<Float>) -> [Float]? = { chunk in
        input.withUnsafeMutableBufferPointer(ofType: Float.self) { buffer, _ in
            for offset in 0..<min(buffer.count, chunk.count) { buffer[offset] = chunk[offset] }
        }
        guard let prediction = try? model.prediction(from: MLDictionaryFeatureProvider(dictionary: ["audio": input])),
              let logProbs = prediction.featureValue(for: "log_probs")?.multiArrayValue else { return nil }
        return MLShapedArray<Float>(converting: logProbs).scalars
    }
    let stems = try FileManager.default.contentsOfDirectory(atPath: takes)
        .filter { $0.hasPrefix("bench-") && $0.hasSuffix(".wav") }
        .map { String($0.dropLast(4)) }
        .sorted()
    var output: [String: Any] = [:]
    for stem in stems {
        let take = try JSONDecoder().decode(Take.self, from: Data(contentsOf: URL(filePath: "\(takes)/\(stem).json")))
        let file = try AVAudioFile(forReading: URL(filePath: "\(takes)/\(stem).wav"))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else { continue }
        try file.read(into: buffer)
        let audio = Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
        var session = ConformerSession(
            words: take.words,
            hidden: Set(take.words.indices),
            start: take.startIndex ?? 0,
            tokenizer: tokenizer,
            classes: tokenizer.blank + 1,
            span: span
        )
        var credited: [Int: Double] = [:]
        var flashes: [[String: Any]] = []
        let clock = ContinuousClock.now
        var heard = 0
        while true {
            heard += ConformerTracker.hopSamples
            let end = min(heard, audio.count + ConformerTracker.lookaheadSamples)
            let done = heard >= audio.count + ConformerTracker.lookaheadSamples
            let before = session.anchorWord
            let update = audio.withUnsafeBufferPointer { session.listen(through: end, audio: $0, done: done, predict: predict) }
            if ProcessInfo.processInfo.environment["TRACE_ANCHOR"] != nil, session.anchorWord != before {
                print("  anchor \(before) -> \(session.anchorWord) at \(Double(end) / 16000)s audio from \(Double(session.anchorSample) / 16000)s")
            }
            for index in update.credits where credited[index] == nil { credited[index] = Double(end) / Double(ConformerTracker.sampleRate) }
            if let flashed = update.flashed {
                flashes.append(["index": flashed, "movedOn": false, "at": Double(end) / Double(ConformerTracker.sampleRate)])
            }
            if done { break }
        }
        let recitable = ConformerAligner(words: take.words, tokenizer: tokenizer, frameSeconds: ConformerTracker.frameSeconds).recitable
        var words: [String: Any] = [:]
        for index in recitable {
            if let at = credited[index] {
                words[String(index)] = ["worst": 0.0, "gop": 0.0, "start": at, "end": at, "credited_at": at]
            } else {
                words[String(index)] = NSNull()
            }
        }
        output[stem] = ["words": words, "heard": "", "hidden": recitable, "misses": flashes]
        print("\(stem) credited \(credited.count)/\(recitable.count) in \(ContinuousClock.now - clock)")
    }
    try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]).write(to: URL(filePath: out))
}

let arguments = CommandLine.arguments
switch arguments.dropFirst().first {
case "tokenize":
    try checkTokenizer(vocabulary: arguments[2], reference: arguments[3])
case "replay":
    try replay(
        takes: arguments[2], windows: arguments[3], model: arguments[4], vocabulary: arguments[5], out: arguments[6],
        quiet: arguments.count > 7 ? Double(arguments[7])! : 2, hiding: arguments.count > 8 ? arguments[8] : "all"
    )
case "live":
    try live(
        takes: arguments[2], model: arguments[3], vocabulary: arguments[4], out: arguments[5],
        span: arguments.count > 6 ? Int(arguments[6])! : ConformerSession.wordSpan
    )
default:
    print("usage: conformer tokenize VOCABULARY REFERENCE | replay TAKES WINDOWS MODEL VOCABULARY OUT")
}
