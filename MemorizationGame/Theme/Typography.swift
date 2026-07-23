import SwiftUI
import CoreText

enum AppFont {
    static let files = [
        "CormorantGaramond-Regular",
        "CormorantGaramond-Medium",
        "CormorantGaramond-SemiBold",
        "CormorantGaramond-Italic"
    ]

    static func register() {
        for file in files {
            guard let url = Bundle.main.url(forResource: file, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func scriptureName(for weight: Font.Weight) -> String {
        switch weight {
        case .medium: return "CormorantGaramond-Medium"
        case .semibold, .bold, .heavy, .black: return "CormorantGaramond-SemiBold"
        default: return "CormorantGaramond-Regular"
        }
    }
}

extension Font {
    /// Content face — reserved for scripture, prayer titles, and the streak numeral.
    static func scripture(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(AppFont.scriptureName(for: weight), size: size)
    }
}

enum Typography {
    // Interface chrome — system sans (SF Pro).
    static let title    = Font.system(size: 20, weight: .semibold)
    static let button   = Font.system(size: 17, weight: .semibold)
    static let subtitle = Font.system(size: 17, weight: .semibold)
    static let body     = Font.system(size: 16, weight: .regular)
    static let callout  = Font.system(size: 15, weight: .regular)
    static let label    = Font.system(size: 13, weight: .medium)
    static let caption  = Font.system(size: 13, weight: .regular)
    static let footnote = Font.system(size: 12, weight: .regular)
    static let micro    = Font.system(size: 11, weight: .regular)

    // Content — Cormorant Garamond.
    static let passageTitle = Font.scripture(21, weight: .semibold)
    static let recite       = Font.scripture(24)
    static let prayer       = Font.scripture(23, weight: .medium)
    static let verse        = Font.scripture(19)
    static let numeral      = Font.scripture(40, weight: .semibold)
}
