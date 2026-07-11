import SwiftUI

struct HeatStrip: View {
    let heats: [Double]
    var animated = true
    var highlight: Int? = nil

    private static let waveSpeed = 13.0
    private static let waveMargin = 4.0
    private static let waveWidth = 1.6

    var body: some View {
        if animated {
            let hasComplete = heats.contains { $0 >= 1 }
            TimelineView(.animation(paused: !hasComplete)) { context in
                row(crest: crestPosition(at: context.date))
            }
        } else {
            row(crest: nil)
        }
    }

    private func row(crest: Double?) -> some View {
        HStack(spacing: 2) {
            ForEach(heats.indices, id: \.self) { i in
                segment(heat: heats[i], glow: crest.map { glowIntensity(index: i, crest: $0) } ?? 0, selected: i == highlight)
            }
        }
    }

    private func crestPosition(at date: Date) -> Double {
        let span = Double(heats.count) + 2 * Self.waveMargin
        let period = span / Self.waveSpeed
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period)
        return -Self.waveMargin + span * t / period
    }

    private func glowIntensity(index: Int, crest: Double) -> Double {
        let distance = Double(index) - crest
        return exp(-distance * distance / (2 * Self.waveWidth * Self.waveWidth))
    }

    @ViewBuilder
    private func segment(heat: Double, glow: Double, selected: Bool) -> some View {
        let complete = heat >= 1
        let hot = Heat.intensity(heat)
        let fill = Heat.color(complete ? 1 : hot * 0.85)
        let shape = RoundedRectangle(cornerRadius: 1.5)
        let base = shape
            .fill(Color.white.opacity(selected ? 0.3 : 0.07))
            .overlay(shape.fill(complete ? fill : fill.opacity(heat > 0 ? 0.35 + 0.65 * hot : 0)))
            .shadow(color: fill.opacity(complete ? 0 : 0.8 * hot * hot), radius: 1 + 3 * hot)
            .scaleEffect(selected ? CGSize(width: 1, height: 2.1) : CGSize(width: 1, height: 1))
        if complete {
            let glowing = base
                .shadow(color: Theme.ember.opacity(0.4), radius: 2)
                .background(
                    ZStack {
                        shape
                            .fill(Theme.ember)
                            .blur(radius: 4)
                            .opacity(0.15 + 0.85 * glow)
                        shape
                            .fill(Theme.emberHot)
                            .blur(radius: 3)
                            .opacity(0.9 * pow(glow, 2.2))
                    }
                )
            glowing
        } else {
            base
        }
    }
}
