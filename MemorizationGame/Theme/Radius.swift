import CoreGraphics

/// Corner radii. Fully rounded elements use `Capsule()`; these cover the
/// fixed-radius surfaces. Centralized so the app's roundness reads as one system.
enum Radius {
    static let line: CGFloat    = 1     // recite line
    static let segment: CGFloat = 1.5   // progress-spine segment
    static let chip: CGFloat    = 6
    static let word: CGFloat    = 6     // in-line word highlight
    static let control: CGFloat = 10
    static let group: CGFloat   = 12    // grouped option sections, list cards
    static let card: CGFloat    = 16
}
