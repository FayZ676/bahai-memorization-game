import Foundation
import Observation

@Observable
final class AppStore {
    private(set) var passages: [Passage]
    private(set) var reviewables: [Reviewable]
    private(set) var practiceLog: PracticeLog
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
            self.settings = snapshot.settings
        } else {
            self.passages = []
            self.reviewables = []
            self.practiceLog = PracticeLog()
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

    func cards(for passage: Passage) -> [Reviewable] {
        reviewables.filter { $0.passageRef == passage.id }
    }

    func queue(for passage: Passage) -> [Reviewable] {
        cards(for: passage).sorted { $0.span.start < $1.span.start }
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

    var hasDecayableChunks: Bool {
        reviewables.contains { $0.lastPracticed != nil && $0.hiddenBaseline > 0 }
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
        persist()
    }

    func setAllWords(_ card: Reviewable, hidden: Bool) {
        mutate(card) { $0.setAllWords(hidden: hidden) }
    }

    func toggleWord(_ card: Reviewable, index: Int) {
        mutate(card) { $0.toggleWord(index) }
    }

    private func mutate(_ card: Reviewable, _ change: (inout Reviewable) -> Void) {
        guard let index = reviewables.firstIndex(where: { $0.id == card.id }) else { return }
        let old = reviewables[index]
        var updated = old
        change(&updated)
        recordPractice(from: old, to: &updated)
        reviewables[index] = updated
        persist()
    }

    private func recordPractice(from old: Reviewable, to updated: inout Reviewable, now: Date = Date()) {
        let newlyHidden = updated.hiddenWords.subtracting(old.hiddenWords).count
        guard newlyHidden > 0 else { return }
        updated.lastPracticed = now
        updated.strength = min(updated.strength + 1, DecayModel.strengthCap)
        updated.hiddenBaseline = updated.hiddenWords.count
        let reachedGoalBefore = practiceLog.reachedGoal()
        practiceLog.record(words: newlyHidden)
        if !reachedGoalBefore && practiceLog.reachedGoal() {
            dailyGoalReached = true
        }
    }

    private struct Snapshot: Codable {
        var passages: [Passage]
        var reviewables: [Reviewable]
        var practiceLog: PracticeLog?
        var settings: AppSettings
    }

    private func persist() {
        let snapshot = Snapshot(
            passages: passages,
            reviewables: reviewables,
            practiceLog: practiceLog,
            settings: settings
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }

    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
