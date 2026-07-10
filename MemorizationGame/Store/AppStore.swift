import Foundation
import Observation

@Observable
final class AppStore {
    private(set) var passages: [Passage]
    private(set) var reviewables: [Reviewable]
    var settings: AppSettings {
        didSet { persist() }
    }

    private let storeURL: URL

    init(filename: String = "store.json") {
        self.storeURL = AppStore.documentsDirectory.appendingPathComponent(filename)

        if let data = try? Data(contentsOf: storeURL),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            self.passages = snapshot.passages
            self.reviewables = snapshot.reviewables
            self.settings = snapshot.settings
        } else {
            self.passages = []
            self.reviewables = []
            self.settings = .default
        }
    }

    var engine: ReviewEngine { ReviewEngine(settings: settings) }

    func cards(for passage: Passage) -> [Reviewable] {
        reviewables.filter { $0.passageRef == passage.id }
    }

    func queue(for passage: Passage) -> [Reviewable] {
        engine.queue(cards(for: passage))
    }

    var passagesSorted: [Passage] {
        passages.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func chunkHeats(for passage: Passage) -> [Double] {
        queue(for: passage).map { card in
            card.wordCount > 0 ? Double(card.hiddenWords.count) / Double(card.wordCount) : 0
        }
    }

    func progress(for passage: Passage) -> (memorized: Int, total: Int) {
        let cards = cards(for: passage)
        let memorized = cards.filter { $0.wordCount > 0 && engine.isFullyHidden($0) }.count
        return (memorized, cards.count)
    }

    func createPassage(title: String, units: [String]) {
        let passage = Passage(title: title.trimmingCharacters(in: .whitespacesAndNewlines))
        passages.append(passage)
        let cards = units.enumerated().map { (i, text) in
            Reviewable(
                passageRef: passage.id,
                span: Span(start: i + 1, end: i + 1),
                expectedText: text,
                hiddenWords: []
            )
        }
        reviewables.append(contentsOf: cards)
        persist()
    }

    func deletePassage(_ passage: Passage) {
        passages.removeAll { $0.id == passage.id }
        reviewables.removeAll { $0.passageRef == passage.id }
        persist()
    }

    func hideMore(_ card: Reviewable) {
        let p = passage(of: card)
        let cards = engine.hideMore(cards(for: p), cardID: card.id)
        replaceCards(for: p, with: cards)
    }

    func setAllWords(_ card: Reviewable, hidden: Bool) {
        let p = passage(of: card)
        let cards = engine.setAllHidden(cards(for: p), cardID: card.id, hidden: hidden)
        replaceCards(for: p, with: cards)
    }

    func toggleWord(_ card: Reviewable, index: Int) {
        let p = passage(of: card)
        var cards = cards(for: p)
        cards = engine.toggleWord(cards, cardID: card.id, index: index)
        replaceCards(for: p, with: cards)
    }

    private func passage(of card: Reviewable) -> Passage {
        passages.first { $0.id == card.passageRef }!
    }

    private func replaceCards(for passage: Passage, with updated: [Reviewable]) {
        reviewables.removeAll { $0.passageRef == passage.id }
        reviewables.append(contentsOf: updated)
        persist()
    }

    private struct Snapshot: Codable {
        var passages: [Passage]
        var reviewables: [Reviewable]
        var settings: AppSettings
    }

    private func persist() {
        let snapshot = Snapshot(passages: passages, reviewables: reviewables, settings: settings)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }

    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
