import UIKit

enum Feedback {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func hide() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func flip() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    static func reveal() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func wordMatched() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 1.0)
    }

    static func recitationMiss() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func scrub() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func navigate(forward: Bool) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle = forward ? .soft : .light
        UIImpactFeedbackGenerator(style: style).impactOccurred(intensity: forward ? 0.8 : 0.6)
    }

    static func sessionComplete() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
