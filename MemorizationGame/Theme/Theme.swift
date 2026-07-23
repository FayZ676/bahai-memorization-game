import SwiftUI
import UIKit

/// The color palette — the single source of truth for every color in the app.
/// Every token is adaptive (light/dark); the app's chosen appearance is set once
/// via `Theme.preferredColorScheme`.
enum Theme {
    // Ground & surfaces
    static let bg        = adaptive(0xECEEE8, 0x0F1512)   // paper
    static let raised    = adaptive(0xFAFBF7, 0x18211D)   // cards, rows
    static let rowBg     = raised
    static let surface   = raised

    // Text
    static let ink       = adaptive(0x1C2521, 0xE7E4DA)
    static let inkBright  = ink
    static let muted     = adaptive(0x6A716B, 0x8C938C)
    static let faint     = adaptive(0x9DA39C, 0x626A64)
    static let navIcon   = muted
    static let disabled  = faint

    // Lines
    static let hairline  = adaptive(0xDFE2DB, 0x2A322D)

    // Signature + semantics
    static let accent      = adaptive(0x2F6E5B, 0x5AAB90)   // pine
    static let accentMuted = adaptive(0xB9BEBA, 0x3A473F)
    static let gold        = adaptive(0xB9863F, 0xD4A65A)   // reward only
    static let warn        = adaptive(0xB4443A, 0xD98A80)   // recitation miss

    /// The app's preferred appearance. `.light` locks the light theme; `nil`
    /// follows the system. Dark values stay defined, so re-enabling dark — or
    /// following the system — is a one-line change here.
    static let preferredColorScheme: ColorScheme? = .light

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
