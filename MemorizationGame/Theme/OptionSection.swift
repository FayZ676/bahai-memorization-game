import SwiftUI

struct OptionSection<Content: View>: View {
    var label: String? = nil
    var icon: String? = nil
    var footer: String? = nil
    @ViewBuilder let content: Content

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
