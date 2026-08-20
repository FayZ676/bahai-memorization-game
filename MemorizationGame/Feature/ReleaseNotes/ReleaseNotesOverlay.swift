import SwiftUI

struct ReleaseNotesOverlay: View {
    @Environment(\.fontScale) private var fontScale
    @State private var listHeight: CGFloat = 0

    let note: ReleaseNote
    let onDismiss: () -> Void

    private var listCap: CGFloat { 400 * fontScale }

    var body: some View {
        ZStack {
            scrim
            card
        }
        .transition(.opacity)
    }

    private var scrim: some View {
        Rectangle()
            .fill(Theme.bg.opacity(0.88))
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            header
            highlights
            dismissButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.xl)
        .cardSurface()
        .padding(.horizontal, Spacing.md)
        .shadow(color: .black.opacity(0.16), radius: 18, y: 6)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Version \(note.version)")
                .appFont(Typography.label)
                .tracking(0.6)
                .foregroundStyle(Theme.faint)

            Text("What's New")
                .appFont(Typography.heading)
                .foregroundStyle(Theme.inkBright)

            Text(note.headline)
                .appFont(Typography.callout)
                .foregroundStyle(Theme.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var highlights: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                ForEach(note.highlights) { highlight in
                    row(for: highlight)
                }
            }
            .padding(.bottom, listHeight > listCap ? Spacing.xl : 0)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: min(listHeight, listCap))
        .fadeEdge(.bottom, height: listHeight > listCap ? 28 : 0, color: Theme.rowBg)
    }

    private func row(for highlight: ReleaseHighlight) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: highlight.symbol)
                .appIcon(16)
                .foregroundStyle(Theme.accent)
                .frame(width: 34 * fontScale, height: 34 * fontScale)
                .background(Theme.bg, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(highlight.title)
                    .appFont(Typography.subtitle)
                    .foregroundStyle(Theme.ink)

                Text(highlight.text)
                    .appFont(Typography.callout)
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var dismissButton: some View {
        Button(action: onDismiss) {
            Text("Continue")
                .appFont(Typography.button)
                .foregroundStyle(Theme.bg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(Theme.accent, in: Capsule(style: .continuous))
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.haptic)
    }
}
