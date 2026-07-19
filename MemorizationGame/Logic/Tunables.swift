import Foundation

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

    var intervalScale: Double {
        switch self {
        case .slow: 1.6
        case .medium: 1.0
        case .fast: 0.6
        }
    }

    var detail: String {
        switch self {
        case .slow:
            "Gentle. A newly learned section rests about five nights before a word slips, and well-drilled ones can rest a month."
        case .medium:
            "Balanced. A newly learned section rests a few nights, and well-drilled ones a few weeks."
        case .fast:
            "Demanding. A newly learned section rests a night or two, and even well-drilled ones return within a couple of weeks."
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

    var decayRate: DecayRate = .medium
    var reminderEnabled: Bool = false
    var reminders: [Reminder] = [Reminder()]

    static let `default` = AppSettings()

    private enum CodingKeys: String, CodingKey {
        case decayRate, reminderEnabled, reminders
        case reminderMinuteOfDay, reminderMessage
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings.default
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
        try container.encode(decayRate, forKey: .decayRate)
        try container.encode(reminderEnabled, forKey: .reminderEnabled)
        try container.encode(reminders, forKey: .reminders)
    }
}
