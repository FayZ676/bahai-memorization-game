import SwiftUI
import Observation

@MainActor
@Observable
final class SessionViewModel {
    let passageID: UUID
    private let store: AppStore

    private(set) var cascading = false
    private var cascadeResetTask: Task<Void, Never>?

    init(passage: Passage, store: AppStore) {
        passageID = passage.id
        self.store = store
    }

    var passage: Passage? {
        store.passage(withID: passageID)
    }

    func isMarked(_ idx: Int) -> Bool {
        passage?.hiddenWords.contains(idx) ?? false
    }

    func toggleWord(_ idx: Int) {
        guard let passage else { return }
        let wasHidden = passage.hiddenWords.contains(idx)
        store.toggleWord(passage, index: idx)
        if wasHidden { Feedback.reveal() } else { Feedback.hideTick() }
    }

    var everyWordHidden: Bool {
        guard let passage else { return false }
        return passage.hiddenWords.count >= passage.wordCount
    }

    var everyWordShowing: Bool {
        passage?.hiddenWords.isEmpty ?? true
    }

    func setAllWords(hidden: Bool) {
        guard let passage else { return }
        let everyWord = Set(passage.words.indices)
        let changing = hidden ? everyWord.subtracting(passage.hiddenWords) : passage.hiddenWords
        ripple(changing)
        cascade {
            store.setAllWords(passage, hidden: hidden)
        }
    }

    var randomHideCount: Int {
        get { store.settings.randomHideCount }
        set { store.settings.randomHideCount = newValue }
    }

    @discardableResult
    func hideRandomWords(_ count: Int, among visible: Set<Int>) -> Bool {
        guard let passage else { return false }
        var hidden: Set<Int> = []
        cascade { hidden = store.hideRandomWords(passage, count: count, among: visible) }
        ripple(hidden)
        return !hidden.isEmpty
    }

    private func cascade(_ mutate: () -> Void) {
        cascadeResetTask?.cancel()
        cascading = true
        mutate()
        cascadeResetTask = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            cascading = false
        }
    }

    private func ripple(_ indices: Set<Int>) {
        guard let passage, !indices.isEmpty else { return }
        let count = passage.words.count
        Feedback.cascadeRipple(delays: indices.map {
            Motion.cascadeDelay($0, of: count) + Motion.fadeDuration
        })
    }
}
