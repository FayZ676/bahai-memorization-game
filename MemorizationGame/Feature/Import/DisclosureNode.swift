import SwiftUI

struct DisclosureNode<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var font: AppTextToken = Typography.body
    var color: Color = Theme.ink
    var tracking: CGFloat = 0
    var indent: CGFloat = 0
    var initiallyExpanded: Bool = false
    let content: Content

    @State private var expanded: Bool

    init(
        title: String,
        subtitle: String? = nil,
        font: AppTextToken = Typography.body,
        color: Color = Theme.ink,
        tracking: CGFloat = 0,
        indent: CGFloat = 0,
        initiallyExpanded: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.font = font
        self.color = color
        self.tracking = tracking
        self.indent = indent
        self.content = content()
        _expanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) { expanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Text(title)
                        .appFont(font)
                        .foregroundStyle(color)
                        .tracking(tracking)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let subtitle {
                        Text(subtitle)
                            .appFont(Typography.footnote)
                            .foregroundStyle(Theme.faint)
                    }
                    Image(systemName: "chevron.right")
                        .appIcon(12, weight: .regular)
                        .foregroundStyle(Theme.faint)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .padding(.leading, 16 + indent)
                .padding(.trailing, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.haptic)

            if expanded {
                content
            }
        }
    }
}
