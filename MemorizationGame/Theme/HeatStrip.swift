import SwiftUI

struct HeatStrip: View {
    let heats: [Double]
    var fading: [Bool] = []
    var animated = true
    var highlight: Int? = nil

    private static let waveSpeed = 13.0
    private static let waveMargin = 4.0
    private static let waveWidth = 1.6
    private static let pulsePeriod = 1.6
    private static let fadingFloor = 0.35

    var body: some View {
        let anyComplete = heats.contains { $0 >= 1 }
        let hasFading = fading.contains(true)
        TimelineView(.animation(paused: !anyComplete && !hasFading)) { context in
            row(
                crest: (animated && anyComplete) ? crestPosition(at: context.date) : nil,
                pulse: pulseLevel(at: context.date),
                time: emberTime(at: context.date)
            )
        }
    }

    private func row(crest: Double?, pulse: Double, time: Double) -> some View {
        HStack(spacing: 2) {
            ForEach(heats.indices, id: \.self) { i in
                segment(
                    heat: heats[i],
                    glow: crest.map { glowIntensity(index: i, crest: $0) } ?? 0,
                    selected: i == highlight,
                    fading: fading.indices.contains(i) && fading[i],
                    pulse: pulse,
                    time: time,
                    seed: Double(i)
                )
            }
        }
    }

    private func emberTime(at date: Date) -> Double {
        date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)
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
    private func segment(heat: Double, glow: Double, selected: Bool, fading: Bool, pulse: Double, time: Double, seed: Double) -> some View {
        let complete = heat >= 1 && !fading
        let hot = fading ? max(Heat.intensity(heat), Self.fadingFloor) : Heat.intensity(heat)
        let fill = Heat.color(complete ? 1 : hot * 0.85)
        let shape = RoundedRectangle(cornerRadius: 1.5)
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
            let headroom: CGFloat = 5
            shape
                .fill(Color.white.opacity(selected ? 0.3 : 0.07))
                .overlay {
                    GeometryReader { geo in
                        EmberFill(
                            time: time,
                            heat: 0.5 + 0.4 * glow,
                            seed: seed,
                            segmentHeight: geo.size.height,
                            flameHeadroom: headroom
                        )
                        .frame(width: geo.size.width, height: geo.size.height + headroom)
                        .offset(y: -headroom)
                    }
                }
                .shadow(color: Theme.ember.opacity(0.3 + 0.5 * glow), radius: 1 + 2.5 * glow)
                .scaleEffect(selected ? CGSize(width: 1, height: 2.1) : CGSize(width: 1, height: 1))
        } else {
            base
        }
    }
}

private struct EmberFill: View {
    let time: Double
    let heat: Double
    let seed: Double
    var segmentHeight: CGFloat
    var flameHeadroom: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: flameHeadroom)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(.white)
                .frame(height: segmentHeight)
        }
        .emberEffect(
            .heatStrip(heat: heat),
            time: time,
            seed: seed,
            maxSampleOffset: CGSize(width: 3, height: flameHeadroom + 2)
        )
        .allowsHitTesting(false)
    }
}
