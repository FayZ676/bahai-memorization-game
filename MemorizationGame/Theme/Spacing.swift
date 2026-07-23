import CoreGraphics

/// The 4-pt spacing scale — the single source of truth for gaps and padding.
/// Prefer these over literal numbers so layout rhythm stays consistent and
/// tunable from one place.
enum Spacing {
    static let hair: CGFloat = 2
    static let xxs:  CGFloat = 4
    static let xs:   CGFloat = 6
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 12
    static let lg:   CGFloat = 16
    static let xl:   CGFloat = 20
    static let screen: CGFloat = 24   // default screen margin
    static let xxl:  CGFloat = 32
    static let xxxl: CGFloat = 40
}
