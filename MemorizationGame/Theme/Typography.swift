import SwiftUI
import CoreText

enum AppFont {
    static let files = [
        "EBGaramond-Regular",
        "EBGaramond-Medium",
        "EBGaramond-SemiBold",
        "EBGaramond-Bold",
        "EBGaramond-Italic",
        "EBGaramond-MediumItalic",
        "EBGaramond-SemiBoldItalic",
        "EBGaramond-BoldItalic"
    ]

    static func register() {
        for file in files {
            guard let url = Bundle.main.url(forResource: file, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func serifName(for weight: Font.Weight, italic: Bool) -> String {
        let stem: String
        switch weight {
        case .medium: stem = "Medium"
        case .semibold: stem = "SemiBold"
        case .bold, .heavy, .black: stem = "Bold"
        default: stem = italic ? "" : "Regular"
        }
        return "EBGaramond-" + stem + (italic ? "Italic" : "")
    }
}

enum TextFace {
    case sans
    case serif

    var opticalScale: CGFloat {
        switch self {
        case .sans: return 1
        case .serif: return 1.08
        }
    }
}

struct AppTextToken {
    let size: CGFloat
    let weight: Font.Weight
    let face: TextFace
    let isItalic: Bool

    init(_ size: CGFloat, weight: Font.Weight = .regular, face: TextFace = .sans, italic: Bool = false) {
        self.size = size
        self.weight = weight
        self.face = face
        self.isItalic = italic
    }

    func weight(_ weight: Font.Weight) -> AppTextToken {
        AppTextToken(size, weight: weight, face: face, italic: isItalic)
    }

    func italic() -> AppTextToken {
        AppTextToken(size, weight: weight, face: face, italic: true)
    }

    func font(scale: CGFloat) -> Font {
        let scaled = size * scale * face.opticalScale
        switch face {
        case .sans:
            let system = Font.system(size: scaled, weight: weight)
            return isItalic ? system.italic() : system
        case .serif:
            return .custom(AppFont.serifName(for: weight, italic: isItalic), size: scaled)
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

    static let heading      = AppTextToken(32, weight: .semibold, face: .serif)
    static let passageTitle = AppTextToken(21, weight: .semibold, face: .serif)

    static let tally        = AppTextToken(22, weight: .light)
    static let recite       = AppTextToken(26, face: .serif)
    static let verse        = AppTextToken(20, face: .serif)
    static let verseInitial = AppTextToken(32, face: .serif)
    static let excerpt      = AppTextToken(15, face: .serif)

    static let attribution  = AppTextToken(20, weight: .semibold, face: .serif, italic: true)
    static let byline       = AppTextToken(13, weight: .semibold, face: .serif, italic: true)
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
