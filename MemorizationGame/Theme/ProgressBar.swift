import SwiftUI

struct ProgressBar: View {
    enum Axis {
        case horizontal
        case vertical
    }

    let heats: [Double]
    var weights: [Int]? = nil
    var animated = true
    var highlight: Int? = nil
    var completion: Double? = nil
    var barHeight: CGFloat? = nil
    var axis: Axis = .horizontal

    private static let spacing: CGFloat = 3
    private static let selectionGap: CGFloat = 2.5

    var body: some View {
        switch axis {
        case .horizontal:
            HStack(spacing: Self.spacing * 2) {
                bar
                    .frame(height: barHeight)
                completionLabel
            }
        case .vertical:
            VStack(spacing: Self.spacing * 2) {
                completionLabel
                bar
                    .frame(width: barHeight)
            }
        }
    }

    @ViewBuilder
    private var completionLabel: some View {
        if let completion {
            Text(Self.percentLabel(completion))
                .appFont(axis == .horizontal ? Typography.footnote : Typography.micro.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Theme.accent)
                .fixedSize()
        }
    }

    private var bar: some View {
        GeometryReader { geo in
            let span = extent(of: geo.size) - Self.spacing * CGFloat(max(heats.count - 1, 0))
            segments(span: span)
                .preference(key: ProgressBarBounds.self, value: geo.frame(in: .global))
        }
    }

    private func extent(of size: CGSize) -> CGFloat {
        axis == .horizontal ? size.width : size.height
    }

    @ViewBuilder
    private func segments(span: CGFloat) -> some View {
        let fractions = normalizedWeights
        switch axis {
        case .horizontal:
            HStack(spacing: Self.spacing) {
                sizedSegments(fractions: fractions, span: span)
            }
        case .vertical:
            VStack(spacing: Self.spacing) {
                sizedSegments(fractions: fractions, span: span)
            }
        }
    }

    private func sizedSegments(fractions: [Double], span: CGFloat) -> some View {
        ForEach(heats.indices, id: \.self) { i in
            segment(heat: heats[i], selected: i == highlight)
                .frame(
                    width: axis == .horizontal ? max(span * fractions[i], 0) : nil,
                    height: axis == .horizontal ? nil : max(span * fractions[i], 0)
                )
        }
    }

    static func percentLabel(_ fraction: Double) -> String {
        "\(percentValue(fraction))%"
    }

    static func percentValue(_ fraction: Double) -> Int {
        let clamped = min(max(fraction, 0), 1)
        switch clamped {
        case 0: return 0
        case 1: return 100
        default: return min(max(Int((clamped * 100).rounded()), 1), 99)
        }
    }

    private static let minShareOfEqual = 0.5
    private static let maxShareOfEqual = 2.0

    private var normalizedWeights: [Double] {
        Self.displayFractions(weights: weights, count: heats.count)
    }

    static func displayFractions(weights: [Int]?, count: Int) -> [Double] {
        let equalShare = 1 / Double(max(count, 1))
        guard let weights, weights.count == count, weights.contains(where: { $0 > 0 }) else {
            return Array(repeating: equalShare, count: count)
        }
        let total = Double(weights.reduce(0, +))
        var fractions = weights.map { Double($0) / total }
        guard count > 1 else { return fractions }
        let floor = minShareOfEqual * equalShare
        let cap = maxShareOfEqual * equalShare
        for _ in 0..<8 {
            fractions = fractions.map { min(max($0, floor), cap) }
            let sum = fractions.reduce(0, +)
            fractions = fractions.map { $0 / sum }
        }
        return fractions
    }

    @ViewBuilder
    private func segment(heat: Double, selected: Bool) -> some View {
        let t = Self.eased(heat)
        let shape = RoundedRectangle(cornerRadius: Radius.segment, style: .continuous)
        shape
            .fill(Theme.ink.opacity(0.08))
            .overlay {
                shape.fill(Theme.accent).opacity(fillOpacity(t))
            }
            .frame(
                maxWidth: axis == .horizontal ? nil : .infinity,
                maxHeight: axis == .horizontal ? .infinity : nil
            )
            .overlay {
                if selected {
                    shape.inset(by: -Self.selectionGap).stroke(Theme.accent, lineWidth: 1.5)
                }
            }
            .zIndex(selected ? 1 : 0)
    }

    private func fillOpacity(_ t: Double) -> Double {
        t <= 0 ? 0 : 0.16 + 0.84 * t
    }

    private static func eased(_ heat: Double) -> Double {
        let x = min(max(heat, 0), 1)
        let k = 2.5
        return (exp(k * x) - 1) / (exp(k) - 1)
    }
}

struct ProgressBarBounds: PreferenceKey {
    static let defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next.width * next.height > value.width * value.height { value = next }
    }
}
