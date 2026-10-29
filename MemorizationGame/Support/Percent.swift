import Foundation

enum Percent {
    static func label(_ fraction: Double) -> String {
        "\(value(fraction))%"
    }

    static func value(_ fraction: Double) -> Int {
        let clamped = min(max(fraction, 0), 1)
        switch clamped {
        case 0: return 0
        case 1: return 100
        default: return min(max(Int((clamped * 100).rounded()), 1), 99)
        }
    }
}
