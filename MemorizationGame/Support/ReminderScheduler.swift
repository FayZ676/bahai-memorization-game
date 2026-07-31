import Foundation
import UserNotifications

enum ReminderScheduler {
    private static let identifierPrefix = "daily-memorization-reminder"
    private static let streakIdentifier = "streak-at-risk-reminder"

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func syncStreakReminder(_ settings: AppSettings, log: PracticeLog) {
        Task {
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: [streakIdentifier])

            guard settings.streakReminderEnabled,
                  let alert = StreakReminder.next(for: log),
                  await hasPermission(promptIfUnasked: true)
            else { return }

            let content = UNMutableNotificationContent()
            content.title = StreakReminder.title(streakLength: alert.streakLength)
            content.body = StreakReminder.body
            content.sound = .default

            let fireTime = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: alert.fireDate
            )
            let request = UNNotificationRequest(
                identifier: streakIdentifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: fireTime, repeats: false)
            )
            try? await center.add(request)
        }
    }

    private static func hasPermission(promptIfUnasked: Bool = false) async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        if status == .notDetermined && promptIfUnasked {
            return await requestPermission()
        }
        return status == .authorized || status == .provisional
    }

    static func sync(_ settings: AppSettings) {
        Task {
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            let ours = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ours)

            guard settings.reminderEnabled, await hasPermission() else { return }

            for reminder in settings.reminders {
                let message = reminder.message.trimmingCharacters(in: .whitespacesAndNewlines)
                let content = UNMutableNotificationContent()
                content.title = "Time to memorize"
                content.body = message.isEmpty ? AppSettings.defaultReminderMessage : message
                content.sound = .default

                var time = DateComponents()
                time.hour = reminder.minuteOfDay / 60
                time.minute = reminder.minuteOfDay % 60
                let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)

                let request = UNNotificationRequest(
                    identifier: "\(identifierPrefix)-\(reminder.id.uuidString)",
                    content: content,
                    trigger: trigger
                )
                try? await center.add(request)
            }
        }
    }
}
