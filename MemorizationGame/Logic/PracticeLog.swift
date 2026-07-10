import Foundation

struct PracticeLog: Codable, Equatable {
    private(set) var wordsByDay: [String: Int] = [:]

    mutating func record(words: Int, on date: Date = Date()) {
        guard words > 0 else { return }
        wordsByDay[Self.dayKey(for: date), default: 0] += words
    }

    func words(on date: Date) -> Int {
        wordsByDay[Self.dayKey(for: date)] ?? 0
    }

    func practiced(on date: Date) -> Bool {
        words(on: date) > 0
    }

    func streak(endingOn today: Date = Date()) -> Int {
        var day = practiced(on: today) ? today : previousDay(of: today)
        var count = 0
        while practiced(on: day) {
            count += 1
            day = previousDay(of: day)
        }
        return count
    }

    func recentDays(_ count: Int, endingOn today: Date = Date()) -> [Date] {
        (0..<count).reversed().compactMap {
            Calendar.current.date(byAdding: .day, value: -$0, to: today)
        }
    }

    private func previousDay(of date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
    }

    static func dayKey(for date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
