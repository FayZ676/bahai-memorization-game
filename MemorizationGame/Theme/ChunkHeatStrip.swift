import SwiftUI

struct ChunkHeatStrip: View {
    let heats: [Double]
    var animated = true

    private static let waveSpeed = 13.0
    private static let waveMargin = 4.0
    private static let waveWidth = 1.6

    private static let heatCurve = 2.5
    private static let coolFill: UInt32 = 0xE7B878
    private static let hotFill: UInt32 = 0xF5A03C

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
                segment(heat: heats[i], glow: crest.map { glowIntensity(index: i, crest: $0) } ?? 0)
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

    private func intensity(_ heat: Double) -> Double {
        (exp(Self.heatCurve * heat) - 1) / (exp(Self.heatCurve) - 1)
    }

    private func heatColor(_ intensity: Double) -> Color {
        let mix = { (shift: Int) -> Double in
            let cool = Double((Self.coolFill >> shift) & 0xFF)
            let hot = Double((Self.hotFill >> shift) & 0xFF)
            return (cool + (hot - cool) * intensity) / 255
        }
        return Color(.sRGB, red: mix(16), green: mix(8), blue: mix(0))
    }

    @ViewBuilder
    private func segment(heat: Double, glow: Double) -> some View {
        let complete = heat >= 1
        let hot = intensity(heat)
        let shape = RoundedRectangle(cornerRadius: 1.5)
        let base = shape
            .fill(Color.white.opacity(0.07))
            .overlay(shape.fill(complete ? Theme.accentBright : heatColor(hot).opacity(hot * 0.72)))
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
            if animated {
                glowing.modifier(LiftMotion())
            } else {
                glowing.offset(y: -2.2)
            }
        } else {
            base
        }
    }
}

private struct LiftMotion: ViewModifier {
    @State private var lifted = false

    func body(content: Content) -> some View {
        content
            .offset(y: lifted ? -2.2 : 0)
            .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: lifted)
            .transaction { $0.animation = nil }
            .onAppear { lifted = true }
    }
}
