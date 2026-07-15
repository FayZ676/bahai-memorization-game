import Foundation

struct DecayModel {
    static let momentumMultiplier: Double = 2
    static let strengthCap: Double = 6

    var baseHalfLifeDays: Double = DecayRate.medium.baseHalfLifeDays

    func halfLifeDays(strength: Double) -> Double {
        baseHalfLifeDays * pow(Self.momentumMultiplier, strength)
    }

    func retention(elapsedDays: Double, strength: Double) -> Double {
        guard elapsedDays > 0 else { return 1 }
        return pow(0.5, elapsedDays / halfLifeDays(strength: strength))
    }

    func targetHidden(for card: Reviewable, at now: Date) -> Int {
        guard let last = card.lastPracticed, card.hiddenBaseline > 0 else {
            return card.hiddenWords.count
        }
        let elapsedDays = (now.timeIntervalSince(last) / 86_400).rounded(.down)
        let retained = retention(elapsedDays: elapsedDays, strength: card.strength)
        let target = Int((retained * Double(card.hiddenBaseline)).rounded())
        return min(max(target, 0), card.hiddenWords.count)
    }

    func decayed(_ card: Reviewable, at now: Date) -> Reviewable {
        let target = targetHidden(for: card, at: now)
        guard target < card.hiddenWords.count else { return card }
        var updated = card
        let ordered = card.hiddenWords.sorted { Self.revealRank(card.id, $0) < Self.revealRank(card.id, $1) }
        updated.hiddenWords = Set(ordered.prefix(target))
        return updated
    }

    static func revealRank(_ id: UUID, _ index: Int) -> UInt64 {
        var hash = UInt64(bitPattern: Int64(index)) &+ 0x9E37_79B9_7F4A_7C15
        withUnsafeBytes(of: id.uuid) { bytes in
            for byte in bytes { hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3 }
        }
        hash ^= hash >> 33
        hash = hash &* 0xFF51_AFD7_ED55_8CCD
        hash ^= hash >> 33
        return hash
    }

    func isDecaying(_ card: Reviewable, at now: Date) -> Bool {
        card.lastPracticed != nil
            && card.hiddenBaseline > 0
            && targetHidden(for: card, at: now) < card.hiddenBaseline
    }

    func lostFraction(_ card: Reviewable, at now: Date) -> Double {
        guard card.hiddenBaseline > 0 else { return 0 }
        let remaining = Double(targetHidden(for: card, at: now)) / Double(card.hiddenBaseline)
        return 1 - remaining
    }

    func wordsLost(_ card: Reviewable, at now: Date) -> Int {
        max(card.hiddenBaseline - targetHidden(for: card, at: now), 0)
    }

    static func nextDecay(for card: Reviewable, after now: Date) -> Date? {
        guard let last = card.lastPracticed, card.hiddenBaseline > 0 else { return nil }
        let elapsedDays = (now.timeIntervalSince(last) / 86_400).rounded(.down)
        return last.addingTimeInterval((elapsedDays + 1) * 86_400)
    }
}
