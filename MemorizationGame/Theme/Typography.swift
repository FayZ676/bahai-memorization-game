import SwiftUI
import CoreText

enum AppFont {
    static let files = [
        "CormorantGaramond-Regular",
        "CormorantGaramond-Medium",
        "CormorantGaramond-SemiBold",
        "CormorantGaramond-Bold",
        "CormorantGaramond-Italic",
        "EBGaramond-Regular",
        "EBGaramond-Medium",
        "EBGaramond-SemiBold",
        "EBGaramond-Bold",
        "EBGaramond-Italic"
    ]

    static func register() {
        for file in files {
            guard let url = Bundle.main.url(forResource: file, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func scriptureName(for weight: Font.Weight) -> String {
        switch weight {
        case .medium: return "EBGaramond-Medium"
        case .semibold: return "EBGaramond-SemiBold"
        case .bold, .heavy, .black: return "EBGaramond-Bold"
        default: return "EBGaramond-Regular"
        }
    }

    static func displayName(for weight: Font.Weight) -> String {
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
    case display
    case scripture

    var opticalScale: CGFloat {
        switch self {
        case .sans: return 1
        case .display: return 1.22
        case .scripture: return 1.08
        }
    }
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

    func weight(_ weight: Font.Weight) -> AppTextToken {
        AppTextToken(size, weight: weight, face: face)
    }

    func font(scale: CGFloat) -> Font {
        let scaled = size * scale * face.opticalScale
        switch face {
        case .sans:
            return .system(size: scaled, weight: weight)
        case .display:
            return .custom(AppFont.displayName(for: weight), size: scaled)
        case .scripture:
            return .custom(AppFont.scriptureName(for: weight), size: scaled)
        }
    }
}

enum Typography {
    static let button   = AppTextToken(17, weight: .semibold)
    static let subtitle = AppTextToken(17, weight: .semibold)
    static let body     = AppTextToken(16, weight: .regular)
    static let callout  = AppTextToken(15, weight: .regular)
    static let label    = AppTextToken(13, weight: .medium)
    static let caption  = AppTextToken(13, weight: .regular)
    static let footnote = AppTextToken(12, weight: .regular)
    static let micro    = AppTextToken(11, weight: .regular)

    static let heading      = AppTextToken(28, weight: .bold, face: .display)
    static let passageTitle = AppTextToken(19, weight: .bold, face: .display)

    static let numeral      = AppTextToken(34, weight: .semibold, face: .scripture)
    static let recite       = AppTextToken(26, face: .scripture)
    static let verse        = AppTextToken(20, face: .scripture)
    static let verseInitial = AppTextToken(32, face: .scripture)
    static let excerpt      = AppTextToken(15, face: .scripture)
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

private struct AppIconModifier: ViewModifier {
    @Environment(\.fontScale) private var scale
    let size: CGFloat
    let weight: Font.Weight

    func body(content: Content) -> some View {
        content.font(.system(size: size * scale, weight: weight))
    }
}

extension View {
    func appFont(_ token: AppTextToken) -> some View {
        modifier(AppFontModifier(token: token))
    }

    func appIcon(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(AppIconModifier(size: size, weight: weight))
    }
}
