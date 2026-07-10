import Foundation

struct StreakTargetPicker {
    let engine: ReviewEngine

    func target(
        passages: [Passage],
        reviewables: [Reviewable],
        recentPassageRefs: [UUID],
        date: Date = Date()
    ) -> (passage: Passage, card: Reviewable)? {
        let ordered = orderedByRecency(passages, recentPassageRefs: recentPassageRefs)
        for passage in ordered {
            if let card = earliestIncompleteChunk(of: passage, in: reviewables) {
                return (passage, card)
            }
        }
        return dailyRandomChunk(from: ordered, in: reviewables, date: date)
    }

    private func orderedByRecency(_ passages: [Passage], recentPassageRefs: [UUID]) -> [Passage] {
        let recent = recentPassageRefs.compactMap { id in passages.first { $0.id == id } }
        return recent + passages.filter { !recent.contains($0) }
    }

    private func earliestIncompleteChunk(of passage: Passage, in reviewables: [Reviewable]) -> Reviewable? {
        queue(for: passage, in: reviewables).first { !engine.isFullyHidden($0) }
    }

    private func dailyRandomChunk(
        from passages: [Passage],
        in reviewables: [Reviewable],
        date: Date
    ) -> (passage: Passage, card: Reviewable)? {
        let all = passages.flatMap { passage in
            queue(for: passage, in: reviewables).map { (passage, $0) }
        }
        guard !all.isEmpty else { return nil }
        return all[dailySeed(for: date) % all.count]
    }

    private func dailySeed(for date: Date) -> Int {
        let hash = PracticeLog.dayKey(for: date).unicodeScalars.reduce(UInt(5381)) {
            ($0 &* 33) &+ UInt($1.value)
        }
        return Int(hash % UInt(Int.max))
    }

    private func queue(for passage: Passage, in reviewables: [Reviewable]) -> [Reviewable] {
        engine.queue(reviewables.filter { $0.passageRef == passage.id })
    }
}
