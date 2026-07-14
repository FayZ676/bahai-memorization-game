import SwiftUI

enum Theme {
    static let bg = Color(hex: 0x131211)

    static let ink = Color(hex: 0xE8E3D8)
    static let inkBright = Color(hex: 0xECE8DF)
    static let muted = Color(hex: 0x8A857A)
    static let faint = Color(hex: 0x6D685F)
    static let disabled = Color(hex: 0x4A463F)
    static let navIcon = Color(hex: 0xC9C4BA)

    static let accent = Color(hex: 0xD9A15A)
    static let accentBright = Color(hex: 0xE7B878)
    static let accentPale = Color(hex: 0xF0D6A8)
    static let accentDeep = Color(hex: 0xC78F45)
    static let accentMuted = Color(hex: 0x3A423F)

    static let ember = Color(hex: 0xC2431B)
    static let emberHot = Color(hex: 0xF5A03C)

    static let hairline = Color.white.opacity(0.06)
    static let surface = Color.white.opacity(0.05)
    static let surfaceFaint = Color.white.opacity(0.03)
    static let rowBg = Color(hex: 0x1B1916)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

extension Font {
    static func scripture(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func eyebrow(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold)
    }
}

struct HapticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Feedback.tap() }
            }
    }
}

extension ButtonStyle where Self == HapticButtonStyle {
    static var haptic: HapticButtonStyle { HapticButtonStyle() }
}

struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = 38

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .background(Theme.surface, in: Circle())
            .overlay(Circle().stroke(Theme.hairline, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.6 : 1)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Feedback.tap() }
            }
    }
}

extension ButtonStyle where Self == IconButtonStyle {
    static var icon: IconButtonStyle { IconButtonStyle() }
}
