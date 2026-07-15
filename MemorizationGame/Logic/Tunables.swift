import Foundation
import SwiftUI

enum AppearanceMode: String, Codable, CaseIterable {
    case system
    case light
    case dark

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct Reminder: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var minuteOfDay: Int = 9 * 60
    var message: String = AppSettings.defaultReminderMessage
}

struct AppSettings: Codable, Equatable {
    static let defaultReminderMessage = "A few minutes with your passages keeps them fresh."

    var appearanceMode: AppearanceMode = .system
    var reminderEnabled: Bool = false
    var reminders: [Reminder] = [Reminder()]

    static let `default` = AppSettings()

    private enum CodingKeys: String, CodingKey {
        case appearanceMode, reminderEnabled, reminders
        case reminderMinuteOfDay, reminderMessage
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings.default
        appearanceMode = try container.decodeIfPresent(AppearanceMode.self, forKey: .appearanceMode) ?? d.appearanceMode
        reminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? d.reminderEnabled
        if let stored = try container.decodeIfPresent([Reminder].self, forKey: .reminders) {
            reminders = stored
        } else {
            let minute = try container.decodeIfPresent(Int.self, forKey: .reminderMinuteOfDay) ?? Reminder().minuteOfDay
            let message = try container.decodeIfPresent(String.self, forKey: .reminderMessage) ?? AppSettings.defaultReminderMessage
            reminders = [Reminder(minuteOfDay: minute, message: message)]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(appearanceMode, forKey: .appearanceMode)
        try container.encode(reminderEnabled, forKey: .reminderEnabled)
        try container.encode(reminders, forKey: .reminders)
    }
}
