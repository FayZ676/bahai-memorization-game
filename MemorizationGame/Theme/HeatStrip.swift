import SwiftUI

/// The progress spine: one flat segment per chunk, each filled with the accent
/// in proportion to how deeply that chunk is hidden. A single-hue ramp — no
/// animation, no glow.
struct HeatStrip: View {
    let heats: [Double]
    var animated = true          // retained for call-site compatibility
    var highlight: Int? = nil

    var body: some View {
        HStack(spacing: 3) {
            ForEach(heats.indices, id: \.self) { i in
                segment(heat: heats[i], selected: i == highlight)
            }
        }
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
            .overlay {
                if selected {
                    shape.strokeBorder(Theme.accent.opacity(0.9), lineWidth: 1)
                }
            }
            .frame(maxHeight: .infinity)
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
