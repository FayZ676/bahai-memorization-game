import SwiftUI

enum Motion {
    static let toggle   = Animation.easeInOut(duration: 0.22)
    static let standard = Animation.easeInOut(duration: 0.28)
    static let handoffDuration = 0.95
    static let handoff  = Animation.easeInOut(duration: handoffDuration)
    static let fadeDuration = 0.35
    static let fade     = Animation.easeInOut(duration: fadeDuration)
    static let lineFadeIn = Animation.easeInOut(duration: fadeDuration).delay(0.5)
    static let focusDuration = 0.25
    static let reveal   = Animation.easeOut(duration: 0.12)
    static let sweep    = Animation.easeOut(duration: 0.4)
    static let sweepStagger = 0.12
    static let focus    = Animation.easeInOut(duration: focusDuration)
    static let celebrate = Animation.spring(duration: 0.9, bounce: 0.25)
    static let celebrationDwell = Duration.seconds(3.2)

    static let caretHold = 0.5
    static let caretPulse = 0.55

    static let cascadeSpan = 0.6

    static func cascadeDelay(_ index: Int, of count: Int) -> Double {
        guard count > 1 else { return 0 }
        let t = Double(index) / Double(count - 1)
        return cascadeSpan * (1 - pow(1 - t, 1.8))
    }
}
