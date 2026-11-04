import SwiftUI

struct InfoNote<Content: View>: View {

    private let token: AppTextToken
    private let color: Color
    private let symbol: String
    private let content: Content

    init(
        _ token: AppTextToken,
        color: Color = Theme.muted,
        symbol: String = "info.circle",
        @ViewBuilder content: () -> Content
    ) {
        self.token = token
        self.color = color
        self.symbol = symbol
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Image(systemName: symbol)
                .appIcon(token.size)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            content
        }
    }
}
