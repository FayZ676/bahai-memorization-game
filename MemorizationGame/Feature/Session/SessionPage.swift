import SwiftUI
import Observation

@MainActor
@Observable
final class PageScroll {
    var top: CGFloat = 0
    private(set) var band = 0
    var viewportHeight: CGFloat = 0

    func update(top: CGFloat) {
        self.top = top
        let step = max(viewportHeight / 2, 1)
        let newBand = Int((top / step).rounded(.down))
        if newBand != band { band = newBand }
    }

    var drawnRange: ClosedRange<CGFloat> {
        let step = max(viewportHeight / 2, 1)
        let start = CGFloat(band) * step
        return (start - viewportHeight)...(start + viewportHeight * 2.5)
    }
}

final class PageCache {
    private var key: Key?
    private var cached: PageLayout?

    private struct Key: Equatable {
        let text: String
        let width: CGFloat
        let metrics: ReadingMetrics
        let displayScale: CGFloat
    }

    func layout(for passage: Passage, width: CGFloat, metrics: ReadingMetrics, displayScale: CGFloat) -> PageLayout {
        let key = Key(text: passage.text, width: width, metrics: metrics, displayScale: displayScale)
        if key == self.key, let cached { return cached }
        let built = PageLayout(
            words: passage.words,
            paragraphs: passage.paragraphs,
            width: width,
            metrics: metrics,
            displayScale: displayScale
        )
        self.key = key
        cached = built
        return built
    }
}

final class PageOrigin {
    var global: CGPoint = .zero
}

struct ParagraphSnap: ScrollTargetBehavior {
    let tops: [CGFloat]
    let isActive: Bool

    private static let reachOfViewport: CGFloat = 0.3

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        guard isActive else { return }
        let proposed = target.rect.minY
        let ceiling = max(context.contentSize.height - context.containerSize.height, 0)
        let reach = context.containerSize.height * Self.reachOfViewport
        guard let nearest = tops
            .filter({ $0 <= ceiling + 1 })
            .min(by: { abs($0 - proposed) < abs($1 - proposed) }),
              abs(nearest - proposed) <= reach else { return }
        target.rect.origin.y = nearest
    }
}

struct PlacedParagraph: Layout {
    let frames: [CGRect]
    let size: CGSize

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        for (subview, frame) in zip(subviews, frames) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
        }
    }
}

struct ParagraphMarker: View {
    let isStart: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "paragraphsign")
                .appIcon(13, weight: .light)
                .foregroundStyle(isStart ? Theme.accent : Theme.faint.opacity(0.45))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.haptic)
        .animation(.easeOut(duration: 0.2), value: isStart)
        .accessibilityLabel("Start here")
        .accessibilityAddTraits(isStart ? .isSelected : [])
    }
}

struct HeatRail: View {
    let density: [Double]
    let pageHeight: CGFloat
    let scroll: PageScroll
    let onSeek: (CGFloat, Bool) -> Void

    @State private var width: CGFloat = 0
    @State private var dragging = false

    private static let trackHeight: CGFloat = 6
    private static let markerDiameter: CGFloat = 14

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Theme.ink.opacity(0.08))
                .overlay(Capsule().fill(gradient))
                .frame(height: Self.trackHeight)
            marker
        }
        .frame(height: 28)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !dragging {
                        dragging = true
                        Feedback.scrub()
                    }
                    seek(to: value.location.x, animated: false)
                }
                .onEnded { value in
                    dragging = false
                    seek(to: value.location.x, animated: true)
                }
        )
        .accessibilityElement()
        .accessibilityLabel("Progress through the prayer")
        .accessibilityHint("Drag to move through the prayer. Brighter stretches have more words hidden.")
    }

    private var marker: some View {
        let center = pageHeight > 0 ? min(max((scroll.top + scroll.viewportHeight / 2) / pageHeight, 0), 1) : 0
        let travel = max(width - Self.markerDiameter, 0)
        return Circle()
            .fill(Theme.raised)
            .overlay(Circle().strokeBorder(Theme.accent, lineWidth: dragging ? 2 : 1.5))
            .frame(width: Self.markerDiameter, height: Self.markerDiameter)
            .offset(x: travel * center)
            .allowsHitTesting(false)
    }

    private var gradient: LinearGradient {
        let stops = density.isEmpty
            ? [Gradient.Stop(color: .clear, location: 0)]
            : density.enumerated().map { index, value in
                Gradient.Stop(
                    color: Theme.accent.opacity(Self.fillOpacity(value)),
                    location: density.count > 1 ? CGFloat(index) / CGFloat(density.count - 1) : 0
                )
            }
        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
    }

    private func seek(to x: CGFloat, animated: Bool) {
        guard width > 0 else { return }
        onSeek(min(max(x / width, 0), 1), animated)
    }

    private static func fillOpacity(_ heat: Double) -> Double {
        let x = min(max(heat, 0), 1)
        guard x > 0 else { return 0 }
        let k = 2.5
        let eased = (exp(k * x) - 1) / (exp(k) - 1)
        return 0.16 + 0.84 * eased
    }
}
