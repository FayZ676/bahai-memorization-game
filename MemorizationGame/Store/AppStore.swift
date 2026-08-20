import Foundation
import Observation

@Observable
final class AppStore {
    private(set) var passages: [Passage]
    private(set) var reviewables: [Reviewable]
    private(set) var practiceLog: PracticeLog
    var dailyGoalReached = false
    var justEarned: Achievement?
    var passageJustMemorized = false
    var settings: AppSettings {
        didSet {
            persist()
            if oldValue.reminderEnabled != settings.reminderEnabled
                || oldValue.reminders != settings.reminders {
                ReminderScheduler.sync(settings)
            }
            if oldValue.streakReminderEnabled != settings.streakReminderEnabled {
                ReminderScheduler.syncStreakReminder(settings, log: practiceLog)
            }
        }
    }

    private let storeURL: URL

    init(filename: String = "store.json") {
        let url = AppStore.documentsDirectory.appendingPathComponent(filename)
        self.storeURL = url

        if let data = try? Data(contentsOf: url),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            self.passages = snapshot.passages
            self.reviewables = snapshot.reviewables
            self.practiceLog = snapshot.practiceLog
            self.settings = snapshot.settings
        } else {
            self.passages = []
            self.reviewables = []
            self.practiceLog = PracticeLog()
            self.settings = .default
        }
    }

    func cards(for passage: Passage) -> [Reviewable] {
        reviewables.filter { $0.passageRef == passage.id }
    }

    func queue(for passage: Passage) -> [Reviewable] {
        cards(for: passage).sorted { $0.span.start < $1.span.start }
    }

    var passagesSorted: [Passage] {
        passages.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var activePassages: [Passage] {
        passagesSorted.filter { !$0.isArchived }
    }

    var archivedPassages: [Passage] {
        passagesSorted.filter(\.isArchived)
    }

    func sectionHeats(for passage: Passage) -> [Double] {
        queue(for: passage).map { card in
            card.wordCount > 0 ? Double(card.hiddenWords.count) / Double(card.wordCount) : 0
        }
    }

    func sectionWeights(for passage: Passage) -> [Int] {
        queue(for: passage).map(\.wordCount)
    }

    func hiddenFraction(for passage: Passage) -> Double {
        let cards = queue(for: passage)
        let total = cards.reduce(0) { $0 + $1.wordCount }
        guard total > 0 else { return 0 }
        let hidden = cards.reduce(0) { $0 + $1.hiddenWords.count }
        return Double(hidden) / Double(total)
    }

    var streakCount: Int {
        practiceLog.streak()
    }

    func mergeableGaps(for passage: Passage) -> [Bool] {
        let q = queue(for: passage)
        guard q.count > 1 else { return [] }
        return (0..<(q.count - 1)).map { isComplete(q[$0]) || isComplete(q[$0 + 1]) }
    }

    func isComplete(_ card: Reviewable) -> Bool {
        card.wordCount > 0 && card.hiddenWords.count == card.wordCount
    }

    func isMemorized(_ passage: Passage) -> Bool {
        let cards = queue(for: passage)
        return !cards.isEmpty && cards.allSatisfy(isComplete)
    }

    func passage(forPrayerID prayerID: Int) -> Passage? {
        passages.first { $0.sourceID == prayerID }
    }

    var memorizedPrayerIDs: Set<Int> {
        Set(passages.filter(isMemorized).compactMap(\.sourceID))
    }

    var memorizedPassageIDs: Set<UUID> {
        Set(passages.filter(isMemorized).map(\.id))
    }

    var earnedAchievementCount: Int {
        let memorized = memorizedPrayerIDs
        return AchievementCatalog.all.count { $0.isEarned(in: memorized) }
    }

    func progress(for achievement: Achievement) -> Double? {
        let qualifying = achievement.requirement.prayerIDs
        let fractions = passages
            .filter { $0.sourceID.map(qualifying.contains) ?? false }
            .map(hiddenFraction(for:))
            .sorted(by: >)
        guard !fractions.isEmpty else { return nil }
        let credited = fractions.prefix(achievement.requirement.count).reduce(0, +)
        return min(credited / Double(achievement.requirement.count), 1)
    }

    func leadingPassage(for achievement: Achievement) -> Passage? {
        let qualifying = achievement.requirement.prayerIDs
        return passages
            .filter { $0.sourceID.map(qualifying.contains) ?? false }
            .filter { !isMemorized($0) }
            .max { hiddenFraction(for: $0) < hiddenFraction(for: $1) }
    }

    func merge(_ card: Reviewable, with next: Reviewable) {
        guard let index = reviewables.firstIndex(where: { $0.id == card.id }),
              reviewables.contains(where: { $0.id == next.id }) else { return }
        var merged = reviewables[index]
        let offset = merged.wordCount
        merged.span.end = next.span.end
        merged.expectedText += "\n" + next.expectedText
        merged.hiddenWords.formUnion(next.hiddenWords.map { $0 + offset })
        reviewables[index] = merged
        reviewables.removeAll { $0.id == next.id }
        persist()
    }

    func createPassage(
        title: String,
        units: [String],
        author: String? = nil,
        section: String? = nil,
        sourceID: Int? = nil
    ) {
        let passage = Passage(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            dateAdded: Date(),
            author: author,
            section: section,
            sourceID: sourceID
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

    func updatePassage(_ passage: Passage, title: String, units: [String]) {
        guard let passageIndex = passages.firstIndex(where: { $0.id == passage.id }) else { return }
        passages[passageIndex].title = title.trimmingCharacters(in: .whitespacesAndNewlines)

        let oldCards = queue(for: passage)
        var oldWords: [String] = []
        var oldHidden: Set<Int> = []
        for card in oldCards {
            let offset = oldWords.count
            oldWords.append(contentsOf: card.words.map(String.init))
            oldHidden.formUnion(card.hiddenWords.map { $0 + offset })
        }

        let unitWords = units.map { Reviewable.tokens(in: $0).map(String.init) }
        let newHidden = HiddenWordAlignment.remap(
            oldWords: oldWords,
            hidden: oldHidden,
            newWords: unitWords.flatMap { $0 }
        )

        var offset = 0
        let cards = units.enumerated().map { (i, text) in
            let count = unitWords[i].count
            let hiddenWords = Set(
                newHidden
                    .filter { $0 >= offset && $0 < offset + count }
                    .map { $0 - offset }
            )
            offset += count
            return Reviewable(
                passageRef: passage.id,
                span: Span(start: i + 1, end: i + 1),
                expectedText: text,
                hiddenWords: hiddenWords
            )
        }

        reviewables.removeAll { $0.passageRef == passage.id }
        reviewables.append(contentsOf: cards)
        persist()
    }

    func setArchived(_ passage: Passage, _ isArchived: Bool) {
        guard let index = passages.firstIndex(where: { $0.id == passage.id }) else { return }
        passages[index].isArchived = isArchived
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
        let memorizedBefore = memorizedPrayerIDs
        let memorizedPassagesBefore = memorizedPassageIDs
        recordPractice(from: old, to: updated)
        reviewables[index] = updated
        announceAchievements(memorizedBefore: memorizedBefore)
        notePassagesMemorized(before: memorizedPassagesBefore)
        persist()
    }

    private func notePassagesMemorized(before: Set<UUID>) {
        guard !memorizedPassageIDs.subtracting(before).isEmpty else { return }
        passageJustMemorized = true
    }

    func markReviewRequested() {
        settings.lastReviewRequestVersion = ReviewPrompt.currentVersion
    }

    func markReleaseNotesSeen() {
        settings.lastSeenReleaseNotesVersion = AppInfo.version
    }

    private func announceAchievements(memorizedBefore: Set<Int>) {
        let memorizedNow = memorizedPrayerIDs
        guard memorizedNow != memorizedBefore else { return }
        justEarned = AchievementCatalog.all.first {
            $0.isEarned(in: memorizedNow) && !$0.isEarned(in: memorizedBefore)
        }
    }

    private func recordPractice(from old: Reviewable, to updated: Reviewable) {
        let newlyHidden = updated.hiddenWords.subtracting(old.hiddenWords).count
        guard newlyHidden > 0 else { return }
        let reachedGoalBefore = practiceLog.reachedGoal()
        practiceLog.record(words: newlyHidden)
        if !reachedGoalBefore && practiceLog.reachedGoal() {
            dailyGoalReached = true
        }
        syncStreakReminder()
    }

    func syncStreakReminder() {
        ReminderScheduler.syncStreakReminder(settings, log: practiceLog)
    }

    private struct Snapshot: Codable {
        var passages: [Passage]
        var reviewables: [Reviewable]
        var practiceLog: PracticeLog
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
