import Foundation
import SwiftUI

enum AppTheme: String, Codable, CaseIterable {
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

enum FontSize: String, Codable, CaseIterable {
    case small
    case medium
    case large

    var label: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }

    var scale: CGFloat {
        switch self {
        case .small: 0.85
        case .medium: 1
        case .large: 1.2
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
    static let seenWhenSnapshotPredatesWelcomeTour = true

    var reminderEnabled: Bool = false
    var reminders: [Reminder] = [Reminder()]
    var streakReminderEnabled: Bool = true
    var appTheme: AppTheme = .light
    var fontSize: FontSize = .medium
    var hasSeenWelcomeTour: Bool = false
    var randomHideCount: Int = 2
    var lastReviewRequestVersion: String?
    var lastSeenReleaseNotesVersion: String?

    static let `default` = AppSettings()

    private enum CodingKeys: String, CodingKey {
        case reminderEnabled, reminders, appTheme, fontSize
        case streakReminderEnabled
        case reminderMinuteOfDay, reminderMessage
        case hasSeenWelcomeTour, hasCompletedOnboarding
        case lastReviewRequestVersion
        case lastSeenReleaseNotesVersion
        case randomHideCount
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings.default
        reminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? d.reminderEnabled
        appTheme = try container.decodeIfPresent(AppTheme.self, forKey: .appTheme) ?? d.appTheme
        fontSize = try container.decodeIfPresent(FontSize.self, forKey: .fontSize) ?? d.fontSize
        streakReminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .streakReminderEnabled) ?? d.streakReminderEnabled
        hasSeenWelcomeTour = try container.decodeIfPresent(Bool.self, forKey: .hasSeenWelcomeTour)
            ?? container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding)
            ?? AppSettings.seenWhenSnapshotPredatesWelcomeTour
        lastReviewRequestVersion = try container.decodeIfPresent(String.self, forKey: .lastReviewRequestVersion)
        lastSeenReleaseNotesVersion = try container.decodeIfPresent(String.self, forKey: .lastSeenReleaseNotesVersion)
        randomHideCount = try container.decodeIfPresent(Int.self, forKey: .randomHideCount) ?? d.randomHideCount
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
        try container.encode(reminderEnabled, forKey: .reminderEnabled)
        try container.encode(reminders, forKey: .reminders)
        try container.encode(streakReminderEnabled, forKey: .streakReminderEnabled)
        try container.encode(appTheme, forKey: .appTheme)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(hasSeenWelcomeTour, forKey: .hasSeenWelcomeTour)
        try container.encodeIfPresent(lastReviewRequestVersion, forKey: .lastReviewRequestVersion)
        try container.encodeIfPresent(lastSeenReleaseNotesVersion, forKey: .lastSeenReleaseNotesVersion)
        try container.encode(randomHideCount, forKey: .randomHideCount)
    }
}
