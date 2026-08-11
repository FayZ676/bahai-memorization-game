import SwiftUI

struct WordPainting {
    private(set) var isActive = false
    private var frames: [Int: CGRect] = [:]
    private var targetHidden: Bool?

    mutating func record(_ frame: CGRect, at index: Int) {
        frames[index] = frame
    }

    func frame(at index: Int) -> CGRect? {
        frames[index]
    }

    func index(at location: CGPoint, wordCount: Int) -> Int? {
        frames.first { index, frame in
            index < wordCount && frame.insetBy(dx: -3.5, dy: -6).contains(location)
        }?.key
    }

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
