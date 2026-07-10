import SwiftUI

struct OptionSection<Content: View>: View {
    var label: String? = nil
    var footer: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let label {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
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
            .background(Theme.rowBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))

            if let footer {
                Text(footer)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.faint)
                    .lineSpacing(2)
                    .padding(.horizontal, 6)
                    .padding(.top, 8)
            }
        }
    }
}
