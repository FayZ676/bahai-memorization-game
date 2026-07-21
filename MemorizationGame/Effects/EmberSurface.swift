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

    static func streakNumber(intensity: Double, heat: Double, azure: Double) -> EmberStyle {
        EmberStyle(
            heat: heat,
            azure: azure,
            scale: 3,
            octaves: 4,
            warp: 1,
            speed: 1,
            sheen: 0,
            intensity: intensity,
            flameReach: 0.34
        )
    }

    static func heatStrip(heat: Double) -> EmberStyle {
        EmberStyle(
            heat: heat,
            azure: 0,
            scale: 1.3,
            octaves: 2,
            warp: 0.6,
            speed: 1,
            sheen: 0.16,
            intensity: 1,
            flameReach: 0.45
        )
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
                    .float(Float(style.flameReach))
                ),
                maxSampleOffset: style.flameReach > 0 ? maxSampleOffset : .zero
            )
        }
    }
}
