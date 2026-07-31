import SwiftUI

struct ScreenHeader: View {
    let title: String
    let onTitleTap: (() -> Void)?
    let leading: AnyView
    let trailing: AnyView

    init(title: String, onTitleTap: (() -> Void)? = nil, @ViewBuilder leading: () -> some View, @ViewBuilder trailing: () -> some View) {
        self.title = title
        self.onTitleTap = onTitleTap
        self.leading = AnyView(leading())
        self.trailing = AnyView(trailing())
    }

    init(title: String, onBack: @escaping () -> Void, onTitleTap: (() -> Void)? = nil, @ViewBuilder trailing: () -> some View) {
        self.init(title: title, onTitleTap: onTitleTap, leading: { BackChevron(action: onBack) }, trailing: trailing)
    }

    init(title: String, onBack: @escaping () -> Void, onTitleTap: (() -> Void)? = nil) {
        self.init(title: title, onBack: onBack, onTitleTap: onTitleTap) { Color.clear }
    }

    var body: some View {
        HStack(spacing: 12) {
            leading
                .frame(width: 38, height: 38)

            Group {
                if let onTitleTap {
                    Button(action: onTitleTap) {
                        titleText
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.haptic)
                } else {
                    titleText
                }
            }
            .frame(maxWidth: .infinity)

            trailing
                .frame(width: 38, height: 38)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 16)
    }

    private var titleText: some View {
        Text(title)
            .appFont(Typography.passageTitle)
            .foregroundStyle(Theme.inkBright)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
    }
}

private struct BackChevron: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.navIcon)
        }
        .buttonStyle(.icon)
    }
}
