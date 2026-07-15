import SwiftUI
import Observation

@MainActor
@Observable
final class SessionViewModel {
    enum Mode {
        case reading
        case practice
    }

    let passage: Passage
    private let store: AppStore

    var mode: Mode = .reading
    var step = 0
    var presentationEpoch = 0

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

    var isPracticing: Bool { mode == .practice }

    func isHidden(_ idx: Int) -> Bool {
        guard mode == .practice, let card = current else { return false }
        return card.hiddenWords.contains(idx)
    }

    func toggleWord(_ idx: Int) {
        guard let card = current, mode == .practice else { return }
        store.toggleWord(card, index: idx)
        Feedback.reveal()
        focus(on: card.id)
    }

    var progressNumber: Int { current?.span.start ?? 0 }
    var progressTotal: Int { max(store.cards(for: passage).count, 1) }
    var chunkHeats: [Double] { store.chunkHeats(for: passage) }

    func start(focusing cardID: UUID? = nil) {
        let q = store.queue(for: passage)
        step = cardID.flatMap { id in q.firstIndex { $0.id == id } }
            ?? q.lastIndex { !$0.hiddenWords.isEmpty }
            ?? 0
        mode = .reading
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
        mode = .reading
        presentationEpoch += 1
        Feedback.scrub()
    }

    func skip(forward: Bool) {
        guard forward ? canGoForward : canGoBack else { return }
        step += forward ? 1 : -1
        mode = .reading
        presentationEpoch += 1
        Feedback.navigate(forward: forward)
    }

    func toggleMode() {
        mode = mode == .practice ? .reading : .practice
        Feedback.flip()
    }

    func setAllWords(hidden: Bool) {
        guard let card = current else { return }
        store.setAllWords(card, hidden: hidden)
        if hidden { Feedback.hide() } else { Feedback.reveal() }
        focus(on: card.id)
    }
}
