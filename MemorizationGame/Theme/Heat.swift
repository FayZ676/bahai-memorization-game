import SwiftUI

enum Heat {
    static let curve = 2.5
    static let stops: [(position: Double, hex: UInt32)] = [
        (0.0, 0x160B07),
        (0.30, 0x6E2410),
        (0.60, 0xC2431B),
        (0.85, 0xF5A03C),
        (1.0, 0xFFDFA0),
    ]

    static func intensity(_ heat: Double) -> Double {
        (exp(curve * heat) - 1) / (exp(curve) - 1)
    }

    static func color(_ intensity: Double) -> Color {
        let upper = stops.firstIndex { $0.position >= intensity } ?? stops.count - 1
        guard upper > 0 else { return Color(hex: stops[0].hex) }
        let lo = stops[upper - 1]
        let hi = stops[upper]
        let t = (intensity - lo.position) / (hi.position - lo.position)
        let mix = { (shift: Int) -> Double in
            let a = Double((lo.hex >> shift) & 0xFF)
            let b = Double((hi.hex >> shift) & 0xFF)
            return (a + (b - a) * t) / 255
        }
        return Color(.sRGB, red: mix(16), green: mix(8), blue: mix(0))
    }
}
