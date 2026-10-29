import SwiftUI

struct WordPainting {
    private(set) var isActive = false
    private var targetHidden: Bool?

    mutating func begin() {
        isActive = true
    }

    mutating func end() {
        targetHidden = nil
    }

    mutating func settle() {
        isActive = false
    }

    mutating func shouldToggle(_ hidden: Bool) -> Bool {
        let target = targetHidden ?? !hidden
        targetHidden = target
        return hidden != target
    }
}

struct PaintRecognizer: UIGestureRecognizerRepresentable {
    let onBegan: (CGPoint) -> Void
    let onMoved: (CGPoint) -> Void
    let onEnded: () -> Void

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = 0.3
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .began: onBegan(recognizer.location(in: nil))
        case .changed: onMoved(recognizer.location(in: nil))
        case .ended, .cancelled, .failed: onEnded()
        default: break
        }
    }
}
