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
    static let strips = 64

    private static let cosines = (0..<points).map { cos(Angle(degrees: -90 + 40 * Double($0)).radians) }
    private static let sines = (0..<points).map { sin(Angle(degrees: -90 + 40 * Double($0)).radians) }

    static let xMin = (centerX + cosines.min()! * radius - strokeHalf) / plate
    static let xSpan = (centerX + cosines.max()! * radius + strokeHalf) / plate - xMin
    static let yMin = (centerY + sines.min()! * radius - strokeHalf) / plate
    static let ySpan = (centerY + sines.max()! * radius + strokeHalf) / plate - yMin

    static let restingStart = xMin + fadeStart * xSpan
    static let gradientWidth = (fadeEnd - fadeStart) * xSpan
    static let offscreenStart = xMin + xSpan * (1 + sAmplitude)

    static func shift(atHeight t: Double) -> Double {
        sAmplitude * xSpan * sin(2 * .pi * (t + sPhase))
    }
}

struct StarFadeMask: View, Animatable {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    private var stops: [Gradient.Stop] {
        let midLocation = (StarFadeGeometry.fadeMid - StarFadeGeometry.fadeStart)
            / (StarFadeGeometry.fadeEnd - StarFadeGeometry.fadeStart)
        return [
            .init(color: .white, location: 0),
            .init(color: .white.opacity(StarFadeGeometry.fadeMidOpacity), location: midLocation),
            .init(color: .white.opacity(0), location: 1),
        ]
    }

    var body: some View {
        Canvas { context, size in
            let gradient = Gradient(stops: stops)
            let leadingEdge = StarFadeGeometry.offscreenStart
                + (StarFadeGeometry.restingStart - StarFadeGeometry.offscreenStart) * progress
            let stripHeight = size.height / Double(StarFadeGeometry.strips)

            for index in 0..<StarFadeGeometry.strips {
                let midY = (Double(index) + 0.5) * stripHeight
                let heightFraction = min(1, max(0, (midY / size.height - StarFadeGeometry.yMin)
                    / StarFadeGeometry.ySpan))
                let start = (leadingEdge + StarFadeGeometry.shift(atHeight: heightFraction)) * size.width
                let strip = Path(CGRect(x: 0, y: Double(index) * stripHeight,
                                        width: size.width, height: stripHeight + 1))

                context.fill(strip, with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: start, y: midY),
                    endPoint: CGPoint(x: start + StarFadeGeometry.gradientWidth * size.width, y: midY)))
            }
        }
    }
}
