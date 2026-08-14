import SwiftUI

enum StarFadeGeometry {
    static let plate = 1024.0
    static let centerX = 512.0
    static let centerY = 508.0
    static let radius = 336.0
    static let strokeHalf = 58.0 / 2 + 12.0
    static let points = 9

    static let fadeStart = 0.15
    static let fadeMid = 0.63
    static let fadeEnd = 0.92
    static let fadeMidOpacity = 0.16
    static let sAmplitude = 0.11
    static let sPhase = 0.5

    private static let cosines = (0..<points).map { cos(Angle(degrees: -90 + 40 * Double($0)).radians) }
    private static let sines = (0..<points).map { sin(Angle(degrees: -90 + 40 * Double($0)).radians) }

    static let xMin = (centerX + cosines.min()! * radius - strokeHalf) / plate
    static let xSpan = (centerX + cosines.max()! * radius + strokeHalf) / plate - xMin
    static let yMin = (centerY + sines.min()! * radius - strokeHalf) / plate
    static let ySpan = (centerY + sines.max()! * radius + strokeHalf) / plate - yMin

    static let gradientWidth = (fadeEnd - fadeStart) * xSpan
    static let untouchedEdge = xMin + xSpan * (1 + sAmplitude)
    static let clearedEdge = xMin - gradientWidth - sAmplitude * xSpan
    static let midLocation = (fadeMid - fadeStart) / (fadeEnd - fadeStart)

    static func leadingEdge(at progress: Double) -> Double {
        untouchedEdge + (clearedEdge - untouchedEdge) * progress
    }
}

struct StarFadeMask: View, Animatable {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(.white)
                .colorEffect(ShaderLibrary.starFade(
                    .float2(proxy.size),
                    .float4(Float(StarFadeGeometry.leadingEdge(at: progress)),
                            Float(StarFadeGeometry.gradientWidth),
                            Float(StarFadeGeometry.sAmplitude * StarFadeGeometry.xSpan),
                            Float(StarFadeGeometry.sPhase)),
                    .float4(Float(StarFadeGeometry.yMin),
                            Float(StarFadeGeometry.ySpan),
                            Float(StarFadeGeometry.midLocation),
                            Float(StarFadeGeometry.fadeMidOpacity))))
        }
    }
}
