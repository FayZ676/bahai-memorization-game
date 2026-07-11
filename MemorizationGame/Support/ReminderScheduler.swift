import Foundation
import UserNotifications

enum ReminderScheduler {
    private static let requestIdentifier = "daily-memorization-reminder"

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func sync(_ settings: AppSettings) {
        Task {
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])

            guard settings.reminderEnabled else { return }
            let status = await center.notificationSettings().authorizationStatus
            guard status == .authorized || status == .provisional else { return }

            let message = settings.reminderMessage.trimmingCharacters(in: .whitespacesAndNewlines)
            let content = UNMutableNotificationContent()
            content.title = "Time to memorize"
            content.body = message.isEmpty ? AppSettings.default.reminderMessage : message
            content.sound = .default

            var time = DateComponents()
            time.hour = settings.reminderMinuteOfDay / 60
            time.minute = settings.reminderMinuteOfDay % 60
            let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)

            let request = UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
}
