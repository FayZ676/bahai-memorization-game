import SwiftUI

struct HeatStrip: View {
    let heats: [Double]
    var fading: [Bool] = []
    var animated = true
    var highlight: Int? = nil
    var mergeableGaps: [Bool] = []

    private static let waveSpeed = 13.0
    private static let waveMargin = 4.0
    private static let waveWidth = 1.6
    private static let pulsePeriod = 1.6
    private static let fadingFloor = 0.35

    var body: some View {
        let hasComplete = animated && heats.contains { $0 >= 1 }
        let hasFading = fading.contains(true)
        let hasMergeable = mergeableGaps.contains(true)
        TimelineView(.animation(paused: !hasComplete && !hasFading && !hasMergeable)) { context in
            row(
                crest: hasComplete ? crestPosition(at: context.date) : nil,
                pulse: pulseLevel(at: context.date)
            )
        }
    }

    private func row(crest: Double?, pulse: Double) -> some View {
        HStack(spacing: 0) {
            ForEach(heats.indices, id: \.self) { i in
                if i > 0 {
                    gap(mergeable: mergeableGaps.indices.contains(i - 1) && mergeableGaps[i - 1], pulse: pulse)
                }
                segment(
                    heat: heats[i],
                    glow: crest.map { glowIntensity(index: i, crest: $0) } ?? 0,
                    selected: i == highlight,
                    fading: fading.indices.contains(i) && fading[i],
                    pulse: pulse
                )
            }
        }
    }

    private func gap(mergeable: Bool, pulse: Double) -> some View {
        Rectangle()
            .fill(mergeable ? Theme.emberHot.opacity(0.9 * pulse) : .clear)
            .frame(width: 2)
            .shadow(color: Theme.emberHot.opacity(mergeable ? 0.7 * pulse : 0), radius: 2)
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

    private func pulseLevel(at date: Date) -> Double {
        let t = date.timeIntervalSinceReferenceDate
        return 0.5 - 0.5 * cos(2 * .pi * t / Self.pulsePeriod)
    }

    @ViewBuilder
    private func segment(heat: Double, glow: Double, selected: Bool, fading: Bool, pulse: Double) -> some View {
        let complete = heat >= 1 && !fading
        let hot = fading ? max(Heat.intensity(heat), Self.fadingFloor) : Heat.intensity(heat)
        let fill = Heat.color(complete ? 1 : hot * 0.85)
        let shape = Rectangle()
        let fillOpacity = fading ? 0.4 + 0.6 * pulse : complete ? 1 : heat > 0 ? 0.35 + 0.65 * hot : 0
        let base = shape
            .fill(Color.white.opacity(selected ? 0.3 : 0.07))
            .overlay(shape.fill(fill.opacity(fillOpacity)))
            .shadow(
                color: fill.opacity(complete ? 0 : fading ? 0.8 * pulse : 0.8 * hot * hot),
                radius: fading ? 1 + 3 * pulse : 1 + 3 * hot
            )
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
