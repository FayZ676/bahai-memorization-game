import Foundation

enum PracticeAge {
    static func days(since lastPracticed: Date?, now: Date, calendar: Calendar = .current) -> Int? {
        guard let lastPracticed else { return nil }
        let then = calendar.startOfDay(for: lastPracticed)
        let today = calendar.startOfDay(for: now)
        return max(calendar.dateComponents([.day], from: then, to: today).day ?? 0, 0)
    }

    static func label(since lastPracticed: Date?, now: Date, calendar: Calendar = .current) -> String {
        switch days(since: lastPracticed, now: now, calendar: calendar) {
        case nil: "Not practiced yet"
        case 0: "Practiced today"
        case 1: "Practiced yesterday"
        case let days?: "\(days) days since practice"
        }
    }
}
