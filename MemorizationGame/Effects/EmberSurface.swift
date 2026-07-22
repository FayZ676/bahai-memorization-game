import SwiftUI

struct EmberStyle {
    var heat: Double
    var azure: Double = 0
    var scale: Double = 3
    var octaves: Int = 4
    var warp: Double = 1
    var speed: Double = 1
    var sheen: Double = 0
    var intensity: Double = 1
    var flameReach: Double = 0
    var flameRise: Double = 0
    var flameDetail: Double = 1
    var stage: Double = -1

    static func streakNumber(intensity: Double, heat: Double, azure: Double, rise: Double) -> EmberStyle {
        EmberStyle(
            heat: heat,
            azure: azure,
            scale: 3,
            octaves: 4,
            warp: 1,
            speed: 1,
            sheen: 0,
            intensity: intensity,
            flameReach: 0.34,
            flameRise: rise,
            flameDetail: 1
        )
    }

    static func blaze(_ level: Double, flames: Bool = false) -> EmberStyle {
        let clamped = min(max(level, 0), 1)
        return EmberStyle(
            heat: clamped,
            azure: EmberGate.azure(clamped),
            scale: 1.3,
            octaves: 2,
            warp: 0.6,
            speed: 1,
            sheen: 0,
            intensity: 1,
            flameReach: flames ? 0.34 : 0,
            flameRise: flames ? clamped : 0,
            flameDetail: flames ? 1 : 0.2,
            stage: EmberGate.stage(clamped)
        )
    }
}

enum EmberGate {
    static let coals = 0.0
    static let smolder = 0.35
    static let fire = 0.7
    static let blazing = 1.0

    static func stage(_ level: Double) -> Double {
        let x = min(max(level, 0), 1)
        if x < smolder { return x / smolder }
        if x < fire { return 1 + (x - smolder) / (fire - smolder) }
        return 2 + (x - fire) / (blazing - fire)
    }

    static func azure(_ level: Double) -> Double {
        smoothstep(0.88, 1.0, level) * 0.6
    }

    private static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}

extension View {
    func emberEffect(_ style: EmberStyle, time: Double, seed: Double = 0, maxSampleOffset: CGSize = .zero) -> some View {
        visualEffect { content, proxy in
            content.layerEffect(
                ShaderLibrary.emberSurface(
                    .float2(proxy.size),
                    .float(Float(time)),
                    .float(Float(seed)),
                    .float(Float(style.heat)),
                    .float(Float(style.azure)),
                    .float(Float(style.scale)),
                    .float(Float(style.octaves)),
                    .float(Float(style.warp)),
                    .float(Float(style.speed)),
                    .float(Float(style.sheen)),
                    .float(Float(style.intensity)),
                    .float(Float(style.flameReach)),
                    .float(Float(style.flameRise)),
                    .float(Float(style.flameDetail)),
                    .float(Float(style.stage))
                ),
                maxSampleOffset: maxSampleOffset
            )
        }
    }
}
