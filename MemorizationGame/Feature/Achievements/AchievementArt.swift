import SwiftUI
import UIKit

/// The art hook: an asset named `achievement.artwork` wins if the catalog has
/// one, otherwise a symbol placeholder stands in. Dropping illustrations into
/// Assets.xcassets under those names is the whole migration.
struct AchievementArt: View {
    let achievement: Achievement
    let earned: Bool
    var size: CGFloat = 84

    var body: some View {
        ZStack {
            Circle()
                .fill(earned ? Theme.gold.opacity(0.14) : Theme.bg)
                .overlay(
                    Circle().stroke(
                        earned ? Theme.gold.opacity(0.55) : Theme.hairline,
                        lineWidth: 1
                    )
                )

            if let artwork = UIImage(named: achievement.artwork) {
                Image(uiImage: artwork)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.12)
                    .clipShape(Circle())
                    .saturation(earned ? 1 : 0)
                    .opacity(earned ? 1 : 0.35)
            } else {
                Image(systemName: earned ? "\(achievement.symbol).fill" : achievement.symbol)
                    .font(.system(size: size * 0.36, weight: .light))
                    .foregroundStyle(earned ? Theme.gold : Theme.faint)
                    .symbolRenderingMode(.monochrome)
            }
        }
        .frame(width: size, height: size)
    }
}
