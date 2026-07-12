import SwiftUI

struct ScreenHeader: View {
    let title: String
    let leading: AnyView
    let trailing: AnyView

    init(title: String, @ViewBuilder leading: () -> some View, @ViewBuilder trailing: () -> some View) {
        self.title = title
        self.leading = AnyView(leading())
        self.trailing = AnyView(trailing())
    }

    init(title: String, onBack: @escaping () -> Void, @ViewBuilder trailing: () -> some View) {
        self.init(title: title, leading: { BackChevron(action: onBack) }, trailing: trailing)
    }

    init(title: String, onBack: @escaping () -> Void) {
        self.init(title: title, onBack: onBack) { Color.clear }
    }

    var body: some View {
        HStack(spacing: 12) {
            leading
                .frame(width: 38, height: 38)

            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(Theme.inkBright)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            trailing
                .frame(width: 38, height: 38)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 16)
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
