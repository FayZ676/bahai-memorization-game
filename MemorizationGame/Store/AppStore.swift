import Foundation
import Observation

@Observable
final class AppStore {
    private(set) var passages: [Passage]
    var passageJustMemorized = false
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

    private static let retiredFiles = ["store.json", "recitation-log.json"]

    init(filename: String = "verses.json") {
        let url = AppStore.documentsDirectory.appendingPathComponent(filename)
        self.storeURL = url
        let returning = Self.retireLegacyData()

        if let data = try? Data(contentsOf: url),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            self.passages = snapshot.passages
            self.settings = snapshot.settings
        } else {
            self.passages = []
            var settings = AppSettings.default
            settings.hasSeenWelcomeTour = returning
            self.settings = settings
        }
    }

    private static func retireLegacyData() -> Bool {
        retiredFiles.reduce(false) { found, name in
            let url = documentsDirectory.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return found }
            try? FileManager.default.removeItem(at: url)
            return true
        }
    }

    func passage(withID id: UUID) -> Passage? {
        passages.first { $0.id == id }
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

    func hiddenFraction(for passage: Passage) -> Double {
        passage.hiddenFraction
    }

    func isMemorized(_ passage: Passage) -> Bool {
        passage.isMemorized
    }

    var memorizedPassageIDs: Set<UUID> {
        Set(passages.filter(isMemorized).map(\.id))
    }

    func createPassage(
        title: String,
        text: String,
        author: String? = nil,
        section: String? = nil,
        sourceID: Int? = nil
    ) {
        let passage = Passage(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            dateAdded: Date(),
            author: author,
            section: section,
            sourceID: sourceID,
            text: text
        )
        passages.append(passage)
        persist()
    }

    func updatePassage(_ passage: Passage, title: String, text: String) {
        guard let index = passages.firstIndex(where: { $0.id == passage.id }) else { return }
        let old = passages[index]
        passages[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        passages[index].text = text
        passages[index].hiddenWords = HiddenWordAlignment.remap(
            oldWords: old.words.map(String.init),
            hidden: old.hiddenWords,
            newWords: Passage.tokens(in: text).map(String.init)
        )
        persist()
    }

    func setArchived(_ passage: Passage, _ isArchived: Bool) {
        guard let index = passages.firstIndex(where: { $0.id == passage.id }) else { return }
        passages[index].isArchived = isArchived
        persist()
    }

    func deletePassage(_ passage: Passage) {
        passages.removeAll { $0.id == passage.id }
        persist()
    }

    func setAllWords(_ passage: Passage, hidden: Bool) {
        mutate(passage) { $0.setAllWords(hidden: hidden) }
    }

    @discardableResult
    func hideRandomWords(_ passage: Passage, count: Int, among visible: Set<Int>) -> Set<Int> {
        guard let current = self.passage(withID: passage.id) else { return [] }
        let candidates = visible.intersection(current.words.indices).subtracting(current.hiddenWords)
        guard !candidates.isEmpty else { return [] }
        let chosen = Set(candidates.shuffled().prefix(count))
        mutate(passage) { $0.hiddenWords.formUnion(chosen) }
        return chosen
    }

    func toggleWord(_ passage: Passage, index: Int) {
        mutate(passage) { $0.toggleWord(index) }
    }

    private func mutate(_ passage: Passage, _ change: (inout Passage) -> Void) {
        guard let index = passages.firstIndex(where: { $0.id == passage.id }) else { return }
        var updated = passages[index]
        change(&updated)
        let memorizedPassagesBefore = memorizedPassageIDs
        passages[index] = updated
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

    private struct Snapshot: Codable {
        var passages: [Passage]
        var settings: AppSettings
    }

    private func persist() {
        let snapshot = Snapshot(passages: passages, settings: settings)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }

    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
