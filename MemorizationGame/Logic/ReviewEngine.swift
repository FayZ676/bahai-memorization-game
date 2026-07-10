import Foundation

struct ReviewEngine {
    let settings: AppSettings

    func queue(_ cards: [Reviewable]) -> [Reviewable] {
        cards.sorted { $0.span.start < $1.span.start }
    }

    func isFullyHidden(_ card: Reviewable) -> Bool {
        card.hiddenWords.count >= card.wordCount
    }

    func hideMore(_ cards: [Reviewable], cardID: UUID) -> [Reviewable] {
        cards.map { c in
            guard c.id == cardID else { return c }
            var updated = c
            let visible = (0..<c.wordCount).filter { !c.hiddenWords.contains($0) }
            updated.hiddenWords.formUnion(visible.prefix(settings.hideAmount))
            return updated
        }
    }

    func setAllHidden(_ cards: [Reviewable], cardID: UUID, hidden: Bool) -> [Reviewable] {
        cards.map { c in
            guard c.id == cardID else { return c }
            var updated = c
            updated.hiddenWords = hidden ? Set(0..<c.wordCount) : []
            return updated
        }
    }

    func toggleWord(_ cards: [Reviewable], cardID: UUID, index: Int) -> [Reviewable] {
        cards.map { c in
            guard c.id == cardID else { return c }
            var updated = c
            if updated.hiddenWords.contains(index) {
                updated.hiddenWords.remove(index)
            } else {
                updated.hiddenWords.insert(index)
            }
            return updated
        }
    }
}
