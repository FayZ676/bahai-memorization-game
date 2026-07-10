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

    static let `default` = AppSettings()

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings.default
        hideAmount = try container.decodeIfPresent(Int.self, forKey: .hideAmount) ?? d.hideAmount
        appearanceMode = try container.decodeIfPresent(AppearanceMode.self, forKey: .appearanceMode) ?? d.appearanceMode
    }
}
