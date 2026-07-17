import Foundation

struct DecayModel {
    static let strengthCap: Double = 5
    static let intervalLadder = [2, 3, 5, 8, 13, 21]
    static let overdueCap = 3

    var rate: DecayRate = .medium

    func intervalNights(strength: Double) -> Int {
        let step = max(min(Int(strength), Self.intervalLadder.count - 1), 0)
        return max(Int((Double(Self.intervalLadder[step]) * rate.intervalScale).rounded()), 1)
    }

    func targetHidden(for card: Reviewable, at now: Date) -> Int {
        guard let last = card.lastPracticed, card.hiddenBaseline > 0 else {
            return card.hiddenWords.count
        }
        let overdue = Self.nightsElapsed(from: last, to: now) - intervalNights(strength: card.strength)
        guard overdue > 0 else { return card.hiddenBaseline }
        let target = card.hiddenBaseline - Self.overdueReveal(overdueNights: overdue)
        return min(max(target, 0), card.hiddenWords.count)
    }

    static func overdueReveal(overdueNights nights: Int) -> Int {
        guard nights > 0 else { return 0 }
        let ramp = min(nights, overdueCap)
        let duringRamp = ramp * (ramp + 1) / 2
        let afterRamp = max(nights - overdueCap, 0) * overdueCap
        return duringRamp + afterRamp
    }

    static func nightsElapsed(from last: Date, to now: Date) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: last)
        let end = calendar.startOfDay(for: now)
        return max(calendar.dateComponents([.day], from: start, to: end).day ?? 0, 0)
    }

    func decayed(_ card: Reviewable, at now: Date) -> Reviewable {
        let target = targetHidden(for: card, at: now)
        guard target < card.hiddenWords.count else { return card }
        var updated = card
        let ordered = card.hiddenWords.sorted { Self.revealRank(card.id, $0) < Self.revealRank(card.id, $1) }
        updated.hiddenWords = Set(ordered.prefix(target))
        return updated
    }

    func revealingFirst(_ card: Reviewable) -> Reviewable {
        guard !card.hiddenWords.isEmpty else { return card }
        var updated = card
        let ordered = card.hiddenWords.sorted { Self.revealRank(card.id, $0) < Self.revealRank(card.id, $1) }
        updated.hiddenWords = Set(ordered.dropLast())
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
        card.hiddenBaseline > 0 && card.hiddenWords.count < card.hiddenBaseline
    }

    func lostFraction(_ card: Reviewable, at now: Date) -> Double {
        guard card.hiddenBaseline > 0 else { return 0 }
        return Double(wordsLost(card, at: now)) / Double(card.hiddenBaseline)
    }

    func wordsLost(_ card: Reviewable, at now: Date) -> Int {
        max(card.hiddenBaseline - card.hiddenWords.count, 0)
    }

    func overdueRatio(_ card: Reviewable, at now: Date) -> Double {
        guard let last = card.lastPracticed, card.hiddenBaseline > 0 else { return -1 }
        return Double(Self.nightsElapsed(from: last, to: now)) / Double(intervalNights(strength: card.strength))
    }
}
