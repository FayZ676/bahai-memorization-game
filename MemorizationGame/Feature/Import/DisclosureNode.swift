import SwiftUI

struct DisclosureNode<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var font: Font = Typography.body
    var color: Color = Theme.ink
    var uppercase: Bool = false
    var tracking: CGFloat = 0
    var indent: CGFloat = 0
    var initiallyExpanded: Bool = false
    let content: Content

    @State private var expanded: Bool

    init(
        title: String,
        subtitle: String? = nil,
        font: Font = Typography.body,
        color: Color = Theme.ink,
        uppercase: Bool = false,
        tracking: CGFloat = 0,
        indent: CGFloat = 0,
        initiallyExpanded: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.font = font
        self.color = color
        self.uppercase = uppercase
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
                        .font(font)
                        .foregroundStyle(color)
                        .textCase(uppercase ? .uppercase : nil)
                        .tracking(tracking)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let subtitle {
                        Text(subtitle)
                            .font(Typography.footnote)
                            .foregroundStyle(Theme.faint)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.muted)
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
