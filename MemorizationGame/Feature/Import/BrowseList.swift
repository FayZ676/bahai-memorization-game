import SwiftUI

struct BrowseList<Content: View>: View {
    let title: String
    let onBack: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Screen {
            ScreenHeader(title: title, onBack: onBack)
        } content: {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    content
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.lg)
            }
        }
    }
}

struct DividedRows<Item: Identifiable, Row: View>: View {
    let items: [Item]
    var leadingInset: CGFloat = Spacing.lg
    var trailingInset: CGFloat = Spacing.lg
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            row(item)
            if index < items.count - 1 {
                Divider()
                    .overlay(Theme.hairline)
                    .padding(.leading, leadingInset)
                    .padding(.trailing, trailingInset)
            }
        }
    }
}

struct EmptyNote: View {
    private let message: String

    init(_ message: String) {
        self.message = message
    }

    var body: some View {
        Text(message)
            .appFont(Typography.body)
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
    }
}
