import SwiftUI

struct MemorizedMoment: View {
    let title: String
    @State private var glowing = false

    private static let starSize: CGFloat = 104

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image("SplashStar")
                .resizable()
                .scaledToFit()
                .frame(width: Self.starSize, height: Self.starSize)
                .scaleEffect(glowing ? 1 : 0.82)
                .shadow(color: Theme.accent.opacity(glowing ? 0.35 : 0), radius: glowing ? Spacing.xl : 0)

            Text("Recited from memory")
                .appFont(Typography.passageTitle)
                .foregroundStyle(Theme.ink)

            Text(title)
                .appFont(Typography.byline)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.vertical, Spacing.screen)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Radius.panel, style: .continuous)
                .fill(Theme.raised)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.panel, style: .continuous)
                        .stroke(Theme.hairline, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.12), radius: 24, y: 8)
        .padding(.horizontal, Spacing.screen)
        .accessibilityElement(children: .combine)
        .onAppear { withAnimation(Motion.celebrate) { glowing = true } }
    }
}
