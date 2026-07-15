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

enum DecayRate: String, Codable, CaseIterable {
    case slow
    case medium
    case fast

    var label: String {
        switch self {
        case .slow: "Slow"
        case .medium: "Medium"
        case .fast: "Fast"
        }
    }

    var baseHalfLifeDays: Double {
        switch self {
        case .slow: 6
        case .medium: 3
        case .fast: 1.5
        }
    }

    var detail: String {
        switch self {
        case .slow:
            "Gentle. A chunk you just finished takes about 12 days without review to fade halfway back."
        case .medium:
            "Balanced. A chunk you just finished takes about 6 days without review to fade halfway back."
        case .fast:
            "Demanding. A chunk you just finished takes about 3 days without review to fade halfway back."
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
    var decayRate: DecayRate = .medium
    var reminderEnabled: Bool = false
    var reminders: [Reminder] = [Reminder()]

    static let `default` = AppSettings()

    private enum CodingKeys: String, CodingKey {
        case appearanceMode, decayRate, reminderEnabled, reminders
        case reminderMinuteOfDay, reminderMessage
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings.default
        appearanceMode = try container.decodeIfPresent(AppearanceMode.self, forKey: .appearanceMode) ?? d.appearanceMode
        decayRate = try container.decodeIfPresent(DecayRate.self, forKey: .decayRate) ?? d.decayRate
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
        try container.encode(decayRate, forKey: .decayRate)
        try container.encode(reminderEnabled, forKey: .reminderEnabled)
        try container.encode(reminders, forKey: .reminders)
    }
}
