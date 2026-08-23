import SwiftUI
import Observation

@MainActor
@Observable
final class SessionViewModel {
    let passage: Passage
    private let store: AppStore

    var step = 0
    var presentationEpoch = 0
    private(set) var concealing = false
    private(set) var cascading = false
    private var cascadeResetTask: Task<Void, Never>?

    init(passage: Passage, store: AppStore) {
        self.passage = passage
        self.store = store
    }

    var current: Reviewable? {
        let q = store.queue(for: passage)
        guard !q.isEmpty else { return nil }
        return q[min(step, q.count - 1)]
    }

    var passageText: String {
        store.queue(for: passage).map(\.expectedText).joined(separator: " ")
    }

    private var queueLength: Int { store.queue(for: passage).count }

    var hasMultipleSections: Bool { queueLength > 1 }

    var canGoForward: Bool { step < queueLength - 1 }
    var canGoBack: Bool { step > 0 }

    func isConcealed(_ idx: Int) -> Bool {
        guard concealing, let card = current else { return false }
        return card.hiddenWords.contains(idx)
    }

    func isMarked(_ idx: Int) -> Bool {
        current?.hiddenWords.contains(idx) ?? false
    }

    func toggleWord(_ idx: Int) {
        guard let card = current, !concealing else { return }
        let wasHidden = card.hiddenWords.contains(idx)
        store.toggleWord(card, index: idx)
        if wasHidden { Feedback.reveal() } else { Feedback.hideTick() }
        focus(on: card.id)
    }

    var everyWordHidden: Bool {
        guard let card = current else { return false }
        return card.hiddenWords.count >= card.wordCount
    }

    var everyWordShowing: Bool {
        current?.hiddenWords.isEmpty ?? true
    }

    var sectionHeats: [Double] { store.sectionHeats(for: passage) }
    var sectionWeights: [Int] { store.sectionWeights(for: passage) }
    var mergeableGaps: [Bool] { store.mergeableGaps(for: passage) }

    var canMerge: Bool {
        let gaps = mergeableGaps
        return gaps.indices.contains(step) && gaps[step]
    }

    func merge() {
        let q = store.queue(for: passage)
        guard canMerge, q.indices.contains(step + 1) else { return }
        store.merge(q[step], with: q[step + 1])
        presentationEpoch += 1
    }

    func start() {
        let q = store.queue(for: passage)
        step = q.lastIndex { !$0.hiddenWords.isEmpty } ?? 0
        concealing = false
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
        presentationEpoch += 1
        Feedback.scrub()
    }

    func skip(forward: Bool) {
        guard forward ? canGoForward : canGoBack else { return }
        step += forward ? 1 : -1
        presentationEpoch += 1
        Feedback.navigate(forward: forward)
    }

    func toggleConcealment() {
        concealing ? reveal() : conceal()
    }

    func conceal() {
        guard !concealing, let card = current, !card.hiddenWords.isEmpty else { return }
        ripple(card.hiddenWords)
        cascade {
            withAnimation(.easeInOut(duration: 0.32)) { concealing = true }
        }
    }

    func reveal() {
        guard concealing else { return }
        ripple(current?.hiddenWords ?? [])
        cascade {
            withAnimation(.easeInOut(duration: 0.32)) { concealing = false }
        }
    }

    func setAllWords(hidden: Bool) {
        guard let card = current else { return }
        let changing = hidden
            ? Set(card.words.indices).subtracting(card.hiddenWords)
            : card.hiddenWords
        ripple(changing)
        cascade {
            store.setAllWords(card, hidden: hidden)
        }
        focus(on: card.id)
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
        guard let card = current, !indices.isEmpty else { return }
        let count = card.words.count
        Feedback.cascadeRipple(delays: indices.map {
            Motion.cascadeDelay($0, of: count) + Motion.fadeDuration
        })
    }
}
