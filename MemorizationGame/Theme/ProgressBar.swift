import SwiftUI

struct ProgressBar: View {
    let heats: [Double]
    var weights: [Int]? = nil
    var animated = true
    var highlight: Int? = nil
    var completion: Double? = nil
    var barHeight: CGFloat? = nil

    private static let spacing: CGFloat = 3

    var body: some View {
        HStack(spacing: Self.spacing * 2) {
            bar
                .frame(height: barHeight)

            if let completion {
                Text(Self.percentLabel(completion))
                    .appFont(Typography.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
                    .fixedSize()
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
            .preference(key: ProgressBarWidth.self, value: geo.size.width)
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
            .frame(maxHeight: .infinity)
            .shadow(color: Theme.ink.opacity(selected ? 0.22 : 0), radius: 3, y: 2)
            .offset(y: selected ? -3 : 0)
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

struct ProgressBarWidth: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
