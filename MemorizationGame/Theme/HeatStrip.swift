import SwiftUI

struct HeatStrip: View {
    let heats: [Double]
    var animated = true
    var highlight: Int? = nil

    private static let waveSpeed = 13.0
    private static let waveMargin = 4.0
    private static let waveWidth = 1.6
    private static let pulsePeriod = 1.6

    var body: some View {
        let anyComplete = heats.contains { $0 >= 1 }
        let alive = anyComplete || heats.contains { $0 > 0 }
        TimelineView(.animation(paused: !alive)) { context in
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
    private func segment(heat: Double, glow: Double, selected: Bool, pulse: Double, time: Double, seed: Double) -> some View {
        let complete = heat >= 1
        let hot = Heat.intensity(heat)
        let shape = RoundedRectangle(cornerRadius: 1.5)
        let scale = selected ? CGSize(width: 1, height: 2.1) : CGSize(width: 1, height: 1)
        let track = shape.fill(Color.white.opacity(selected ? 0.3 : 0.07))

        if heat <= 0 {
            track.scaleEffect(scale)
        } else if complete {
            let breath = 0.6 + 0.4 * pulse
            track
                .overlay {
                    EmberFill(style: .blaze(EmberGate.blazing), time: time, seed: seed)
                }
                .shadow(color: Theme.ember.opacity((0.3 + 0.5 * glow) * breath), radius: (1 + 2.5 * glow) * breath)
                .scaleEffect(scale)
        } else {
            track
                .overlay {
                    EmberFill(style: .blaze(heat * EmberGate.fire), time: time, seed: seed)
                }
                .shadow(color: Heat.color(hot).opacity(0.8 * hot * hot), radius: 1 + 3 * hot)
                .scaleEffect(scale)
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        HeatStrip(heats: stride(from: 0.05, through: 1.0, by: 0.05).map { $0 })
            .frame(height: 10)
        HeatStrip(heats: [0.6, 0.3, 0.15])
            .frame(height: 10)
    }
    .padding(24)
    .background(Color.black)
}

private struct EmberFill: View {
    let style: EmberStyle
    let time: Double
    let seed: Double

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(.white)
            .emberEffect(
                style,
                time: time,
                seed: seed,
                maxSampleOffset: CGSize(width: 12, height: 8)
            )
            .allowsHitTesting(false)
    }
}
