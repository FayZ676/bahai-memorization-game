import UIKit

enum Feedback {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func hide() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func hideTick() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
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

    static func burn() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred(intensity: CGFloat.random(in: 0.5...0.8))
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.03...0.06)) {
            generator.impactOccurred(intensity: CGFloat.random(in: 0.25...0.45))
        }
    }
}
