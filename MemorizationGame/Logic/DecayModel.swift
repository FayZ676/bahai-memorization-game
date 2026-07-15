import Foundation

struct DecayModel {
    static let baseHalfLifeDays: Double = 1
    static let momentumMultiplier: Double = 1.8
    static let strengthCap: Double = 6

    static func halfLifeDays(strength: Double) -> Double {
        baseHalfLifeDays * pow(momentumMultiplier, strength)
    }

    static func retention(elapsedDays: Double, strength: Double) -> Double {
        guard elapsedDays > 0 else { return 1 }
        return pow(0.5, elapsedDays / halfLifeDays(strength: strength))
    }

    static func targetHidden(for card: Reviewable, at now: Date) -> Int {
        guard let last = card.lastPracticed, card.hiddenBaseline > 0 else {
            return card.hiddenWords.count
        }
        let elapsedDays = now.timeIntervalSince(last) / 86_400
        let retained = retention(elapsedDays: elapsedDays, strength: card.strength)
        let target = Int((retained * Double(card.hiddenBaseline)).rounded())
        return min(max(target, 0), card.hiddenWords.count)
    }

    static func decayed(_ card: Reviewable, at now: Date) -> Reviewable {
        let target = targetHidden(for: card, at: now)
        guard target < card.hiddenWords.count else { return card }
        var updated = card
        let ordered = card.hiddenWords.sorted(by: >)
        updated.hiddenWords = Set(ordered.suffix(target))
        return updated
    }

    static func isDecaying(_ card: Reviewable, at now: Date) -> Bool {
        card.lastPracticed != nil
            && card.hiddenBaseline > 0
            && targetHidden(for: card, at: now) < card.hiddenBaseline
    }

    static func lostFraction(_ card: Reviewable, at now: Date) -> Double {
        guard card.hiddenBaseline > 0 else { return 0 }
        let remaining = Double(targetHidden(for: card, at: now)) / Double(card.hiddenBaseline)
        return 1 - remaining
    }
}
