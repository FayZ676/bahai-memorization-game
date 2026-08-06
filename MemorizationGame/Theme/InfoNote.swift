import SwiftUI

struct InfoNote<Content: View>: View {
    @Environment(\.fontScale) private var scale

    private let token: AppTextToken
    private let color: Color
    private let content: Content

    init(_ token: AppTextToken, color: Color = Theme.muted, @ViewBuilder content: () -> Content) {
        self.token = token
        self.color = color
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Image(systemName: "info.circle")
                .font(.system(size: token.size * scale))
                .foregroundStyle(color)
                .accessibilityHidden(true)
            content
        }
    }
}
