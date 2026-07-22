import Foundation
import Observation

@Observable
final class AppStore {
    private(set) var passages: [Passage]
    private(set) var reviewables: [Reviewable]
    private(set) var practiceLog: PracticeLog
    private var lastSoftFloor: Date?
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
            self.lastSoftFloor = snapshot.lastSoftFloor
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
        var updated = reviewables.map { model.decayed($0, at: now) }
        if !updated.contains(where: { model.isDecaying($0, at: now) }),
           !Calendar.current.isDate(lastSoftFloor ?? .distantPast, inSameDayAs: now),
           let index = softFloorIndex(in: updated, model: model, at: now) {
            updated[index] = model.revealingFirst(updated[index])
            lastSoftFloor = now
        }
        guard updated != reviewables else { return }
        reviewables = updated
        persist()
    }

    private func softFloorIndex(in cards: [Reviewable], model: DecayModel, at now: Date) -> Int? {
        cards.indices
            .filter {
                cards[$0].lastPracticed != nil
                    && cards[$0].hiddenBaseline > 0
                    && cards[$0].hiddenWords.count == cards[$0].hiddenBaseline
            }
            .max { model.overdueRatio(cards[$0], at: now) < model.overdueRatio(cards[$1], at: now) }
    }

    var decay: DecayModel { DecayModel(rate: settings.decayRate) }

    func cards(for passage: Passage) -> [Reviewable] {
        reviewables.filter { $0.passageRef == passage.id }
    }

    func queue(for passage: Passage) -> [Reviewable] {
        cards(for: passage).sorted { $0.span.start < $1.span.start }
    }

    var passagesSorted: [Passage] {
        passages.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func sectionHeats(for passage: Passage) -> [Double] {
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

    func mergeableGaps(for passage: Passage) -> [Bool] {
        let q = queue(for: passage)
        guard q.count > 1 else { return [] }
        return (0..<(q.count - 1)).map { isComplete(q[$0]) && isComplete(q[$0 + 1]) }
    }

    func isComplete(_ card: Reviewable) -> Bool {
        card.wordCount > 0 && card.hiddenWords.count == card.wordCount
    }

    func merge(_ card: Reviewable, with next: Reviewable) {
        guard let index = reviewables.firstIndex(where: { $0.id == card.id }),
              let nextIndex = reviewables.firstIndex(where: { $0.id == next.id }) else { return }
        var merged = reviewables[index]
        let offset = merged.wordCount
        merged.span.end = next.span.end
        merged.expectedText += "\n" + next.expectedText
        merged.hiddenWords.formUnion(next.hiddenWords.map { $0 + offset })
        merged.strength = min(merged.strength, next.strength)
        merged.lastPracticed = [merged.lastPracticed, next.lastPracticed].compactMap { $0 }.min()
        merged.hiddenBaseline = merged.hiddenWords.count
        reviewables[index] = merged
        reviewables.removeAll { $0.id == next.id }
        persist()
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
        var lastSoftFloor: Date?
    }

    private func persist() {
        let snapshot = Snapshot(
            passages: passages,
            reviewables: reviewables,
            practiceLog: practiceLog,
            settings: settings,
            lastSoftFloor: lastSoftFloor
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }

    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
