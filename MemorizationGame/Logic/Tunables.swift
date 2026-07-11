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

struct AppSettings: Codable, Equatable {
    var hideAmount: Int = 3
    var appearanceMode: AppearanceMode = .system
    var reminderEnabled: Bool = false
    var reminderMinuteOfDay: Int = 9 * 60
    var reminderMessage: String = "A few minutes with your passages keeps them fresh."

    static let `default` = AppSettings()

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings.default
        hideAmount = try container.decodeIfPresent(Int.self, forKey: .hideAmount) ?? d.hideAmount
        appearanceMode = try container.decodeIfPresent(AppearanceMode.self, forKey: .appearanceMode) ?? d.appearanceMode
        reminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? d.reminderEnabled
        reminderMinuteOfDay = try container.decodeIfPresent(Int.self, forKey: .reminderMinuteOfDay) ?? d.reminderMinuteOfDay
        reminderMessage = try container.decodeIfPresent(String.self, forKey: .reminderMessage) ?? d.reminderMessage
    }
}
