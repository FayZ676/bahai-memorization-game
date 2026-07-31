import SwiftUI
import UIKit

/// The color palette — the single source of truth for every color in the app.
/// Every token is adaptive (light/dark); the app's chosen appearance is set once
/// via `Theme.preferredColorScheme`.
enum Theme {
    // Ground & surfaces
    static let bg        = adaptive(0xECEEE8, 0x121212)   // paper
    static let raised    = adaptive(0xFAFBF7, 0x1E1E1E)   // cards, rows
    static let rowBg     = raised
    static let surface   = raised

    // Text
    static let ink       = adaptive(0x1C2521, 0xEDEDED)
    static let inkBright  = ink
    static let muted     = adaptive(0x6A716B, 0x9A9A9A)
    static let faint     = adaptive(0x9DA39C, 0x6A6A6A)
    static let navIcon   = muted
    static let disabled  = faint

    // Lines
    static let hairline  = adaptive(0xDFE2DB, 0x2E2E2E)

    // Signature + semantics
    static let accent      = adaptive(0x2F6E5B, 0xC89A5A)   // pine on paper, gilt on ink
    static let accentMuted = adaptive(0xB9BEBA, 0x4A3D28)
    static let gold        = adaptive(0xB9863F, 0xF0CE8A)   // reward only
    static let warn        = adaptive(0xB4443A, 0xD98A80)   // recitation miss

    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
