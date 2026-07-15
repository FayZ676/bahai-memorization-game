import Foundation
import Observation

@Observable
final class AppStore {
    private(set) var passages: [Passage]
    private(set) var reviewables: [Reviewable]
    private(set) var practiceLog: PracticeLog
    private(set) var recentPassageRefs: [UUID]
    var dailyGoalReached = false
    var settings: AppSettings {
        didSet {
            persist()
            if oldValue.reminderEnabled != settings.reminderEnabled
                || oldValue.reminders != settings.reminders {
                ReminderScheduler.sync(settings)
            }
        }
    }

    private let storeURL: URL

    init(filename: String = "store.json") {
        self.storeURL = AppStore.documentsDirectory.appendingPathComponent(filename)

        if let data = try? Data(contentsOf: storeURL),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            self.passages = snapshot.passages
            self.reviewables = snapshot.reviewables
            self.practiceLog = snapshot.practiceLog ?? PracticeLog()
            self.recentPassageRefs = snapshot.recentPassageRefs
                ?? snapshot.lastPracticedPassageRef.map { [$0] }
                ?? []
            self.settings = snapshot.settings
        } else {
            self.passages = []
            self.reviewables = []
            self.practiceLog = PracticeLog()
            self.recentPassageRefs = []
            self.settings = .default
        }

        applyDecay()
    }

    func applyDecay(at now: Date = Date()) {
        let model = decay
        let decayed = reviewables.map { model.decayed($0, at: now) }
        guard decayed != reviewables else { return }
        reviewables = decayed
        persist()
    }

    var decay: DecayModel { DecayModel(baseHalfLifeDays: settings.decayRate.baseHalfLifeDays) }

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

    var practicedToday: Bool {
        practiceLog.practiced(on: Date())
    }

    var streakCount: Int {
        practiceLog.streak()
    }

    func decayingChunks(at now: Date = Date()) -> [(passage: Passage, card: Reviewable)] {
        let model = decay
        return reviewables
            .filter { model.isDecaying($0, at: now) }
            .sorted { model.lostFraction($0, at: now) > model.lostFraction($1, at: now) }
            .compactMap { card in
                passages.first { $0.id == card.passageRef }.map { ($0, card) }
            }
    }

    func progress(for passage: Passage) -> (memorized: Int, total: Int) {
        let cards = cards(for: passage)
        let memorized = cards.filter { $0.wordCount > 0 && engine.isFullyHidden($0) }.count
        return (memorized, cards.count)
    }

    func createPassage(title: String, units: [String]) {
        let passage = Passage(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            dateAdded: Date()
        )
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
        recentPassageRefs.removeAll { $0 == passage.id }
        persist()
    }

    func setAllWords(_ card: Reviewable, hidden: Bool) {
        let p = passage(of: card)
        var cards = engine.setAllHidden(cards(for: p), cardID: card.id, hidden: hidden)
        recordPractice(from: card, in: &cards, passage: p)
        replaceCards(for: p, with: cards)
    }

    func toggleWord(_ card: Reviewable, index: Int) {
        let p = passage(of: card)
        var cards = engine.toggleWord(cards(for: p), cardID: card.id, index: index)
        recordPractice(from: card, in: &cards, passage: p)
        replaceCards(for: p, with: cards)
    }

    private func recordPractice(from old: Reviewable, in updated: inout [Reviewable], passage: Passage, now: Date = Date()) {
        guard let index = updated.firstIndex(where: { $0.id == old.id }) else { return }
        let newlyHidden = updated[index].hiddenWords.subtracting(old.hiddenWords).count
        guard newlyHidden > 0 else { return }
        updated[index].lastPracticed = now
        updated[index].strength = min(updated[index].strength + 1, DecayModel.strengthCap)
        updated[index].hiddenBaseline = updated[index].hiddenWords.count
        let reachedGoalBefore = practiceLog.reachedGoal()
        practiceLog.record(words: newlyHidden)
        if !reachedGoalBefore && practiceLog.reachedGoal() {
            dailyGoalReached = true
        }
        recentPassageRefs.removeAll { $0 == passage.id }
        recentPassageRefs.insert(passage.id, at: 0)
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
        var practiceLog: PracticeLog?
        var recentPassageRefs: [UUID]?
        var lastPracticedPassageRef: UUID?
        var settings: AppSettings
    }

    private func persist() {
        let snapshot = Snapshot(
            passages: passages,
            reviewables: reviewables,
            practiceLog: practiceLog,
            recentPassageRefs: recentPassageRefs,
            lastPracticedPassageRef: nil,
            settings: settings
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }

    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
