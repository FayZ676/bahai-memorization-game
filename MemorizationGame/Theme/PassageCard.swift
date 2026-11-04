import SwiftUI

struct PassageCard<Accessory: View>: View {
    let title: String
    var author: String? = nil
    var section: String? = nil
    var detail: String? = nil
    @ViewBuilder var accessory: Accessory

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .appFont(Typography.passageTitle)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .truncationMode(.tail)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Spacing.xs) {
                        authorText
                        if author != nil, section != nil {
                            Text("·")
                        }
                        sectionText
                            .fixedSize()
                        Spacer(minLength: Spacing.sm)
                        detailText
                    }

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        authorText
                        HStack(spacing: Spacing.xs) {
                            sectionText
                            Spacer(minLength: Spacing.sm)
                            detailText
                        }
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

    @ViewBuilder private var authorText: some View {
        if let author {
            Text(author)
                .appFont(Typography.byline)
                .lineLimit(1)
                .fixedSize()
        }
    }

    @ViewBuilder private var sectionText: some View {
        if let section {
            Text(section)
                .lineLimit(1)
        }
    }

    @ViewBuilder private var detailText: some View {
        if let detail {
            Text(detail)
                .appFont(Typography.footnote)
                .fixedSize()
        }
    }
}

extension PassageCard where Accessory == EmptyView {
    init(title: String, author: String? = nil, section: String? = nil, detail: String? = nil) {
        self.init(title: title, author: author, section: section, detail: detail) { EmptyView() }
    }
}
