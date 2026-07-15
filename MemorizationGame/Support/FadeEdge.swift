import SwiftUI

struct FadeEdge: ViewModifier {
    var edge: VerticalEdge = .bottom
    var height: CGFloat = 36
    var color: Color = Theme.bg

    func body(content: Content) -> some View {
        content.overlay(alignment: edge == .top ? .top : .bottom) {
            LinearGradient(
                colors: edge == .top ? [color, color.opacity(0)] : [color.opacity(0), color],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height)
            .allowsHitTesting(false)
        }
    }
}

extension View {
    func fadeEdge(_ edge: VerticalEdge = .bottom, height: CGFloat = 36, color: Color = Theme.bg) -> some View {
        modifier(FadeEdge(edge: edge, height: height, color: color))
    }
}
