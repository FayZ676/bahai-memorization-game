import SwiftUI

struct FlameDay: Equatable {
    let words: Int
    let heat: Double
}

enum FlameScale {
    static let firstSpark = 3.0
    static let whiteHot = 180.0
    static let azureStart = 96.0
    static let azureFull = 192.0
    static let frozenTime = 4.2

    static func intensity(words: Int) -> Double {
        let raw = log1p(Double(words) / firstSpark) / log1p(whiteHot / firstSpark)
        return min(max(raw, 0), 1)
    }

    static func blue(words: Int) -> Double {
        let t = min(max((Double(words) - azureStart) / (azureFull - azureStart), 0), 1)
        return t * t * (3 - 2 * t)
    }

    static func time(at date: Date, reduceMotion: Bool) -> Double {
        reduceMotion ? frozenTime : date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)
    }
}

struct BurningNumberView: View {
    let value: Int
    let today: FlameDay
    var fontSize: CGFloat = 54
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var flameReach: CGSize { CGSize(width: fontSize * 0.6, height: fontSize * 1.05) }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let time = FlameScale.time(at: context.date, reduceMotion: reduceMotion)
            let style = EmberStyle.streakNumber(
                intensity: FlameScale.intensity(words: today.words),
                heat: max(today.heat, 0.3),
                azure: FlameScale.blue(words: today.words)
            )
            Text("\(value)")
                .font(.display(fontSize))
                .lineLimit(1)
                .foregroundStyle(.white)
                .padding(.horizontal, flameReach.width)
                .padding(.top, flameReach.height)
                .emberEffect(style, time: time, maxSampleOffset: flameReach)
                .padding(.horizontal, -flameReach.width)
        }
    }
}
