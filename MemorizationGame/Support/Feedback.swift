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

    private static let matchGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let missGenerator = UINotificationFeedbackGenerator()

    /// Re-primed after every firing: an unprepared generator waits for the Taptic Engine to spin
    /// up, which reads as the match confirmation lagging the highlight it accompanies.
    static func prepareRecitation() {
        matchGenerator.prepare()
        missGenerator.prepare()
    }

    static func wordMatched() {
        matchGenerator.impactOccurred(intensity: 1.0)
        matchGenerator.prepare()
    }

    static func recitationMiss() {
        missGenerator.notificationOccurred(.error)
        missGenerator.prepare()
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

    private static var rippleItems: [DispatchWorkItem] = []

    static func cascadeRipple(delays: [Double]) {
        rippleItems.forEach { $0.cancel() }
        rippleItems = []
        let sorted = delays.sorted()
        guard let span = sorted.last, span > 0 else { return }
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        var lastScheduled = -Double.infinity
        for delay in sorted {
            guard delay - lastScheduled >= 0.05 else { continue }
            lastScheduled = delay
            let intensity = 0.35 + 0.3 * (delay / span)
            let item = DispatchWorkItem { generator.impactOccurred(intensity: intensity) }
            rippleItems.append(item)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        }
    }

    static func burn() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred(intensity: CGFloat.random(in: 0.5...0.8))
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.03...0.06)) {
            generator.impactOccurred(intensity: CGFloat.random(in: 0.25...0.45))
        }
    }
}
