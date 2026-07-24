import SwiftUI

/// Animation timings — the single source of truth for motion. Motion is reserved
/// for hide/reveal, navigation, and rewards; the page is otherwise still.
enum Motion {
    static let micro    = Animation.easeInOut(duration: 0.12)   // taps, toggles
    static let toggle   = Animation.easeInOut(duration: 0.22)   // hide / show a word
    static let standard = Animation.easeInOut(duration: 0.28)   // navigation, layout
    static let fadeDuration = 0.35
    static let fade     = Animation.easeInOut(duration: fadeDuration)   // the word fade
    static let lineFadeIn = Animation.easeInOut(duration: fadeDuration).delay(0.5)
    static let snap     = Animation.spring(response: 0.34, dampingFraction: 0.8)

    static let cascadeSpan = 0.6

    static func cascadeDelay(_ index: Int, of count: Int) -> Double {
        guard count > 1 else { return 0 }
        let t = Double(index) / Double(count - 1)
        return cascadeSpan * (1 - pow(1 - t, 1.8))
    }
}
