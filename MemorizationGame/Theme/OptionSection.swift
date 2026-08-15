import SwiftUI

struct OptionSection<Content: View, Accessory: View>: View {
    var label: String? = nil
    var icon: String? = nil
    var footer: String? = nil
    @ViewBuilder let content: Content
    @ViewBuilder let accessory: Accessory

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let label {
                HStack(spacing: 6) {
                    if let icon {
                        Image(systemName: icon)
                            .appIcon(11, weight: .semibold)
                    }
                    Text(label)
                        .appFont(Typography.footnote)
                        .tracking(0.3)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: Spacing.sm)
                    accessory
                }
                .foregroundStyle(Theme.faint)
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
            }

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface(cornerRadius: Radius.group)

            if let footer {
                Text(footer)
                    .appFont(Typography.caption)
                    .foregroundStyle(Theme.faint)
                    .lineSpacing(2)
                    .padding(.horizontal, 6)
                    .padding(.top, 8)
            }
        }
    }
}

extension OptionSection where Accessory == EmptyView {
    init(
        label: String? = nil,
        icon: String? = nil,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(label: label, icon: icon, footer: footer, content: content) { EmptyView() }
    }
}

extension View {
    func optionRow() -> some View {
        padding(.vertical, Spacing.md)
            .padding(.horizontal, Spacing.lg)
    }
}

struct DisclosureRow: View {
    private let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(title)
                .appFont(Typography.body)
                .foregroundStyle(Theme.ink)
            Spacer()
            Image(systemName: "chevron.right")
                .appIcon(13, weight: .semibold)
                .foregroundStyle(Theme.faint)
        }
        .optionRow()
        .contentShape(Rectangle())
    }
}
