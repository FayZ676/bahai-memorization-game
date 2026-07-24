import SwiftUI
import CoreText

enum AppFont {
    static let files = [
        "CormorantGaramond-Regular",
        "CormorantGaramond-Medium",
        "CormorantGaramond-SemiBold",
        "CormorantGaramond-Bold",
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
        case .semibold: return "CormorantGaramond-SemiBold"
        case .bold, .heavy, .black: return "CormorantGaramond-Bold"
        default: return "CormorantGaramond-Regular"
        }
    }
}

enum TextFace {
    case sans
    case scripture
}

struct AppTextToken {
    let size: CGFloat
    let weight: Font.Weight
    let face: TextFace

    init(_ size: CGFloat, weight: Font.Weight = .regular, face: TextFace = .sans) {
        self.size = size
        self.weight = weight
        self.face = face
    }

    func font(scale: CGFloat) -> Font {
        let scaled = size * scale
        switch face {
        case .sans:
            return .system(size: scaled, weight: weight)
        case .scripture:
            return .custom(AppFont.scriptureName(for: weight), size: scaled)
        }
    }
}

enum Typography {
    // Interface chrome — system sans (SF Pro).
    static let button   = AppTextToken(17, weight: .semibold)
    static let subtitle = AppTextToken(17, weight: .semibold)
    static let body     = AppTextToken(16, weight: .regular)
    static let callout  = AppTextToken(15, weight: .regular)
    static let label    = AppTextToken(13, weight: .medium)
    static let caption  = AppTextToken(13, weight: .regular)
    static let footnote = AppTextToken(12, weight: .regular)
    static let micro    = AppTextToken(11, weight: .regular)

    // Content — Cormorant Garamond.
    static let heading      = AppTextToken(28, weight: .bold, face: .scripture)
    static let passageTitle = AppTextToken(21, weight: .bold, face: .scripture)
    static let recite       = AppTextToken(24, face: .scripture)
    static let prayer       = AppTextToken(23, weight: .medium, face: .scripture)
    static let verse        = AppTextToken(19, face: .scripture)
    static let numeral      = AppTextToken(40, weight: .semibold, face: .scripture)
}

private struct FontScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

extension EnvironmentValues {
    var fontScale: CGFloat {
        get { self[FontScaleKey.self] }
        set { self[FontScaleKey.self] = newValue }
    }
}

private struct AppFontModifier: ViewModifier {
    @Environment(\.fontScale) private var scale
    let token: AppTextToken

    func body(content: Content) -> some View {
        content.font(token.font(scale: scale))
    }
}

extension View {
    func appFont(_ token: AppTextToken) -> some View {
        modifier(AppFontModifier(token: token))
    }
}
