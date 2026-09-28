import SwiftUI

final class WordFrames {
    private var frames: [Int: CGRect] = [:]

    func record(_ frame: CGRect, at index: Int) {
        frames[index] = frame
    }

    func frame(at index: Int) -> CGRect? {
        frames[index]
    }

    func index(at location: CGPoint, wordCount: Int) -> Int? {
        frames
            .filter { index, frame in
                index < wordCount && frame.insetBy(dx: -3.5, dy: -6).contains(location)
            }
            .min { Self.squaredDistance(from: location, to: $0.value) < Self.squaredDistance(from: location, to: $1.value) }?
            .key
    }

    private static func squaredDistance(from point: CGPoint, to frame: CGRect) -> CGFloat {
        let dx = max(frame.minX - point.x, 0, point.x - frame.maxX)
        let dy = max(frame.minY - point.y, 0, point.y - frame.maxY)
        return dx * dx + dy * dy
    }
}

final class ScrollOffset {
    var y: CGFloat = 0
}

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

struct ScrollReach: Equatable {
    var top: CGFloat = 0
    var bottom: CGFloat = 0

    var atTop: Bool { top <= 4 }
    var atBottom: Bool { bottom <= 4 }
}
