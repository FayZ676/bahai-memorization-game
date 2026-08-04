import SwiftUI

/// The progress spine: one flat segment per chunk, each filled with the accent
/// in proportion to how deeply that chunk is hidden. A single-hue ramp — no
/// animation, no glow.
struct ProgressBar: View {
    let heats: [Double]
    var weights: [Int]? = nil
    var animated = true          // retained for call-site compatibility
    var highlight: Int? = nil
    var completion: Double? = nil
    var barHeight: CGFloat? = nil

    private static let spacing: CGFloat = 3

    var body: some View {
        HStack(spacing: Spacing.md) {
            bar
                .frame(height: barHeight)

            if let completion {
                Text(Self.percentLabel(completion))
                    .appFont(Typography.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
                    .frame(width: 34, alignment: .trailing)
            }
        }
    }

    private var bar: some View {
        GeometryReader { geo in
            let fractions = normalizedWeights
            let available = geo.size.width - Self.spacing * CGFloat(max(heats.count - 1, 0))
            HStack(spacing: Self.spacing) {
                ForEach(heats.indices, id: \.self) { i in
                    segment(heat: heats[i], selected: i == highlight)
                        .frame(width: max(available * fractions[i], 0))
                }
            }
        }
    }

    static func percentLabel(_ fraction: Double) -> String {
        let clamped = min(max(fraction, 0), 1)
        let percent: Int
        switch clamped {
        case 0: percent = 0
        case 1: percent = 100
        default: percent = min(max(Int((clamped * 100).rounded()), 1), 99)
        }
        return "\(percent)%"
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
            .frame(maxHeight: .infinity)
            .shadow(color: Theme.ink.opacity(selected ? 0.22 : 0), radius: 3, y: 2)
            .offset(y: selected ? -3 : 0)
            .zIndex(selected ? 1 : 0)
    }

    private func fillOpacity(_ t: Double) -> Double {
        t <= 0 ? 0 : 0.16 + 0.84 * t
    }

    /// Eases mastery (0…1) so the ramp reads perceptually rather than linearly.
    private static func eased(_ heat: Double) -> Double {
        let x = min(max(heat, 0), 1)
        let k = 2.5
        return (exp(k * x) - 1) / (exp(k) - 1)
    }
}
