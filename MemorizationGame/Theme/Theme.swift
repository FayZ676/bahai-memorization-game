import SwiftUI
import UIKit

enum Theme {
    static let bg        = adaptive(0xECEEE8, 0x121212)
    static let raised    = adaptive(0xFAFBF7, 0x1E1E1E)
    static let rowBg     = raised
    static let surface   = raised

    static let ink       = adaptive(0x1C2521, 0xEDEDED)
    static let inkBright  = ink
    static let muted     = adaptive(0x6A716B, 0x9A9A9A)
    static let faint     = adaptive(0x9DA39C, 0x6A6A6A)
    static let navIcon   = muted
    static let disabled  = faint

    static let hairline  = adaptive(0xDFE2DB, 0x2E2E2E)

    static let accent      = adaptive(0x2F6E5B, 0xC89A5A)
    static let accentMuted = adaptive(0xB9BEBA, 0x4A3D28)
    static let gold        = adaptive(0xB9863F, 0xF0CE8A)
    static let warn        = adaptive(0xB4443A, 0xD98A80)

    static let landed      = adaptive(0x2E7D32, 0x66BB6A)
    static let missed      = adaptive(0xD32F2F, 0xFF6B6B)
    static let retried     = adaptive(0xE2650A, 0xFFA149)
    static let skipped     = adaptive(0xC49000, 0xFFD54F)

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
