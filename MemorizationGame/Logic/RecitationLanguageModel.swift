import CryptoKit
import Foundation
import Speech

actor RecitationLanguageModel {
    static let shared = RecitationLanguageModel()

    private var builds: [String: Task<SFSpeechLanguageModel.Configuration?, Never>] = [:]

    func configuration(for text: String) async -> SFSpeechLanguageModel.Configuration? {
        let key = Self.fingerprint(text)
        if let existing = builds[key] { return await existing.value }
        let build = Task { await Self.build(text, key: key) }
        builds[key] = build
        return await build.value
    }

    private static let locale = Locale(identifier: "en-US")
    private static let identifier = "com.faizififita.MemorizationGame.recitation"
    private static let windows = [3, 5]
    private static let phraseWeight = 20
    private static let customizationWeight = 0.9

    private static func build(_ text: String, key: String) async -> SFSpeechLanguageModel.Configuration? {
        let phrases = phrases(in: text)
        guard !phrases.isEmpty, let directory = cacheDirectory() else { return nil }

        let training = directory.appending(path: "\(key).bin")
        let model = directory.appending(path: "\(key).lm")
        let vocabulary = directory.appending(path: "\(key).voc")
        let configuration = SFSpeechLanguageModel.Configuration(
            languageModel: model,
            vocabulary: vocabulary,
            weight: NSNumber(value: customizationWeight)
        )

        if FileManager.default.fileExists(atPath: model.path(percentEncoded: false)) {
            return configuration
        }

        do {
            if !FileManager.default.fileExists(atPath: training.path(percentEncoded: false)) {
                let data = SFCustomLanguageModelData(
                    locale: locale,
                    identifier: identifier,
                    version: "1"
                )
                for phrase in phrases {
                    data.insert(phraseCount: .init(phrase: phrase, count: phraseWeight))
                }
                try await data.export(to: training)
            }
            try await SFSpeechLanguageModel.prepareCustomLanguageModel(
                for: training,
                configuration: configuration
            )
            return configuration
        } catch {
            return nil
        }
    }

    private static func phrases(in text: String) -> [String] {
        let words = text
            .split(whereSeparator: { $0 == " " || $0 == "\n" })
            .map(String.init)
        guard !words.isEmpty else { return [] }

        var seen: Set<String> = []
        var result: [String] = []
        func append(_ phrase: String) {
            guard seen.insert(phrase).inserted else { return }
            result.append(phrase)
        }

        append(words.joined(separator: " "))
        for size in windows where words.count >= size {
            for start in 0...(words.count - size) {
                append(words[start..<(start + size)].joined(separator: " "))
            }
        }
        return result
    }

    private static func fingerprint(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
            .prefix(16)
            .lowercased()
    }

    private static func cacheDirectory() -> URL? {
        guard let base = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first else { return nil }
        let directory = base.appending(path: "RecitationModels")
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }
}
