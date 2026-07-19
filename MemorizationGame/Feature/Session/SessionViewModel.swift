import SwiftUI
import Observation

@MainActor
@Observable
final class SessionViewModel {
    let passage: Passage
    private let store: AppStore

    var step = 0
    var presentationEpoch = 0
    private(set) var isPeeking = false
    private(set) var grounding = false
    private var groundingTask: Task<Void, Never>?

    init(passage: Passage, store: AppStore) {
        self.passage = passage
        self.store = store
    }

    var current: Reviewable? {
        let q = store.queue(for: passage)
        guard !q.isEmpty else { return nil }
        return q[min(step, q.count - 1)]
    }

    private var queueLength: Int { store.queue(for: passage).count }

    var canGoForward: Bool { step < queueLength - 1 }
    var canGoBack: Bool { step > 0 }

    var wordsRevealed: Bool { isPeeking || grounding }

    func isHidden(_ idx: Int) -> Bool {
        guard !wordsRevealed, let card = current else { return false }
        return card.hiddenWords.contains(idx)
    }

    func toggleWord(_ idx: Int) {
        guard let card = current, !wordsRevealed else { return }
        store.toggleWord(card, index: idx)
        Feedback.reveal()
        focus(on: card.id)
    }

    var progressNumber: Int { current?.span.start ?? 0 }
    var progressTotal: Int { max(store.cards(for: passage).count, 1) }
    var sectionHeats: [Double] { store.sectionHeats(for: passage) }

    func start() {
        let q = store.queue(for: passage)
        step = q.lastIndex { !$0.hiddenWords.isEmpty } ?? 0
        beginGrounding()
        presentationEpoch += 1
    }

    private func focus(on cardID: UUID) {
        guard let idx = store.queue(for: passage).firstIndex(where: { $0.id == cardID }) else { return }
        step = idx
    }

    func scrub(to index: Int) {
        let target = max(0, min(index, queueLength - 1))
        guard target != step else { return }
        step = target
        beginGrounding()
        presentationEpoch += 1
        Feedback.scrub()
    }

    func skip(forward: Bool) {
        guard forward ? canGoForward : canGoBack else { return }
        step += forward ? 1 : -1
        beginGrounding()
        presentationEpoch += 1
        Feedback.navigate(forward: forward)
    }

    func togglePeek() {
        groundingTask?.cancel()
        grounding = false
        withAnimation(.easeInOut(duration: 0.32)) { isPeeking.toggle() }
        Feedback.flip()
    }

    func endPeek() {
        guard isPeeking else { return }
        withAnimation(.easeInOut(duration: 0.32)) { isPeeking = false }
    }

    private func beginGrounding() {
        groundingTask?.cancel()
        isPeeking = false
        grounding = true
        groundingTask = Task {
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.6)) { grounding = false }
        }
    }

    func setAllWords(hidden: Bool) {
        guard let card = current else { return }
        store.setAllWords(card, hidden: hidden)
        if hidden { Feedback.hide() } else { Feedback.reveal() }
        focus(on: card.id)
    }
}
