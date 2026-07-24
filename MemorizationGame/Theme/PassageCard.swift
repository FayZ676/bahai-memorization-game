import SwiftUI

struct PassageCard<Accessory: View>: View {
    let title: String
    var author: String? = nil
    var section: String? = nil
    var detail: String? = nil
    @ViewBuilder var accessory: Accessory

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .appFont(Typography.passageTitle)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .truncationMode(.tail)

                HStack(spacing: Spacing.xs) {
                    if let author {
                        Text(author)
                            .italic()
                    }
                    if let section {
                        if author != nil {
                            Text("·")
                        }
                        Text(section)
                            .lineLimit(1)
                    }

                    Spacer(minLength: Spacing.sm)

                    if let detail {
                        Text(detail)
                            .fixedSize()
                    }
                }
                .appFont(Typography.footnote)
                .foregroundStyle(Theme.faint)
            }

            accessory
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

extension PassageCard where Accessory == EmptyView {
    init(title: String, author: String? = nil, section: String? = nil, detail: String? = nil) {
        self.init(title: title, author: author, section: section, detail: detail) { EmptyView() }
    }
}
