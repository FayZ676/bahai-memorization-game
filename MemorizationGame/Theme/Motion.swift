import SwiftUI

/// Animation timings — the single source of truth for motion. Motion is reserved
/// for hide/reveal, navigation, and rewards; the page is otherwise still.
enum Motion {
    static let micro    = Animation.easeInOut(duration: 0.12)   // taps, toggles
    static let toggle   = Animation.easeInOut(duration: 0.22)   // hide / show a word
    static let standard = Animation.easeInOut(duration: 0.28)   // navigation, layout
    static let fade     = Animation.easeInOut(duration: 0.35)   // the word fade
    static let snap     = Animation.spring(response: 0.34, dampingFraction: 0.8)
}
