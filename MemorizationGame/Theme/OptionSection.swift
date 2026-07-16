import SwiftUI

struct OptionSection<Content: View>: View {
    var label: String? = nil
    var footer: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let label {
                Text(label)
                    .font(Typography.footnote)
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.faint)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 8)
            }

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface(cornerRadius: 12)

            if let footer {
                Text(footer)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.faint)
                    .lineSpacing(2)
                    .padding(.horizontal, 6)
                    .padding(.top, 8)
            }
        }
    }
}
