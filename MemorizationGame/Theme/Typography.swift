import SwiftUI
import CoreText

enum AppFont {
    static let files = [
        "Marcellus-Regular",
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
    static func display(_ size: CGFloat) -> Font {
        .custom("Marcellus-Regular", size: size)
    }

    static func scripture(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(AppFont.scriptureName(for: weight), size: size)
    }
}

enum Typography {
    static let title = Font.display(21)
    static let button = Font.display(18)
    static let subtitle = Font.display(17)
    static let body = Font.display(16)
    static let callout = Font.display(15)
    static let label = Font.display(14)
    static let caption = Font.display(13)
    static let footnote = Font.display(12)
    static let micro = Font.display(11)

    static let recite = Font.scripture(24)
    static let prayer = Font.scripture(23, weight: .medium)
    static let verse = Font.scripture(19)
}
