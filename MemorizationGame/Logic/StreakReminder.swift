import Foundation

enum StreakReminder {
    static let hourOfDay = 20

    struct Alert: Equatable {
        var fireDate: Date
        var streakLength: Int
    }

    static func next(
        for log: PracticeLog,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Alert? {
        let streak = log.streak(endingOn: now)
        guard streak > 0 else { return nil }

        let riskDay = log.practiced(on: now)
            ? calendar.date(byAdding: .day, value: 1, to: now)
            : now
        guard let riskDay,
              let fireDate = calendar.date(bySettingHour: hourOfDay, minute: 0, second: 0, of: riskDay),
              fireDate > now
        else { return nil }

        return Alert(fireDate: fireDate, streakLength: streak)
    }

    static func title(streakLength: Int) -> String {
        streakLength == 1
            ? "Your streak is at risk"
            : "Your \(streakLength)-day streak is at risk"
    }

    static let body = "Practice before the day is out to keep it going."
}
