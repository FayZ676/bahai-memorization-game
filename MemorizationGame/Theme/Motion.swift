import SwiftUI

enum Motion {
    static let toggle   = Animation.easeInOut(duration: 0.22)
    static let standard = Animation.easeInOut(duration: 0.28)
    static let fadeDuration = 0.35
    static let fade     = Animation.easeInOut(duration: fadeDuration)
    static let lineFadeIn = Animation.easeInOut(duration: fadeDuration).delay(0.5)

    static let cascadeSpan = 0.6

    static func cascadeDelay(_ index: Int, of count: Int) -> Double {
        guard count > 1 else { return 0 }
        let t = Double(index) / Double(count - 1)
        return cascadeSpan * (1 - pow(1 - t, 1.8))
    }
}
