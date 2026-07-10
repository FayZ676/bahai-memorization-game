import SwiftUI

struct FadeEdge: ViewModifier {
    var height: CGFloat = 36
    var color: Color = Theme.bg

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            LinearGradient(
                colors: [color.opacity(0), color],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height)
            .allowsHitTesting(false)
        }
    }
}

extension View {
    func scriptureFadeEdge(height: CGFloat = 36, color: Color = Theme.bg) -> some View {
        modifier(FadeEdge(height: height, color: color))
    }
}
