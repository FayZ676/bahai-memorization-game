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

struct WeekFireView: View {
    let days: [FlameDay]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let time = Float(FlameScale.time(at: context.date, reduceMotion: reduceMotion))
            Rectangle()
                .visualEffect { [days] content, proxy in
                    content.colorEffect(ShaderLibrary.weekFire(
                        .float2(proxy.size),
                        .float(time),
                        .floatArray(days.map { Float(FlameScale.intensity(words: $0.words)) }),
                        .floatArray(days.map { Float($0.heat) }),
                        .floatArray(days.map { Float(FlameScale.blue(words: $0.words)) }),
                        .floatArray(days.map { $0.words > 0 ? 0 : 1 })
                    ))
                }
        }
    }
}

struct BurningNumberView: View {
    let value: Int
    let today: FlameDay
    var fontSize: CGFloat = 54
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var frameSize: CGSize { CGSize(width: fontSize * 1.4, height: fontSize * 1.5) }
    private var flameReach: CGSize { CGSize(width: fontSize * 0.3, height: fontSize * 0.74) }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let time = Float(FlameScale.time(at: context.date, reduceMotion: reduceMotion))
            let intensity = Float(FlameScale.intensity(words: today.words))
            let heat = Float(max(today.heat, 0.3))
            let blue = Float(FlameScale.blue(words: today.words))
            Text("\(value)")
                .font(.display(fontSize))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .foregroundStyle(.white)
                .frame(width: frameSize.width, height: frameSize.height, alignment: .bottom)
                .visualEffect { [flameReach] content, proxy in
                    content.layerEffect(
                        ShaderLibrary.burningNumber(
                            .float2(proxy.size),
                            .float(time),
                            .float(intensity),
                            .float(heat),
                            .float(blue)
                        ),
                        maxSampleOffset: flameReach
                    )
                }
        }
    }
}
