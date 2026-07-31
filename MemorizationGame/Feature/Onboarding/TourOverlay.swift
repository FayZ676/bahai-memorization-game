import SwiftUI

struct TourOverlay: View {
    let step: TourStep
    let spotlight: CGRect?
    let size: CGSize
    let onSkip: () -> Void
    let onFinish: () -> Void

    private static let gap: CGFloat = 14
    private static let topInset: CGFloat = 64
    private static let bottomInset: CGFloat = 132

    var body: some View {
        ZStack {
            if spotlight != nil || step == .finished {
                scrim.transition(.opacity)
            }
            placedCard
        }
        .animation(Motion.standard, value: step)
        .animation(Motion.standard, value: spotlight)
    }

    private var scrim: some View {
        Rectangle()
            .fill(Theme.bg.opacity(0.88))
            .mask {
                ZStack {
                    Rectangle()
                    if let spotlight {
                        RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                            .frame(width: spotlight.width + 14, height: spotlight.height + 12)
                            .position(x: spotlight.midX, y: spotlight.midY)
                            .blendMode(.destinationOut)
                    }
                }
                .compositingGroup()
            }
            .overlay {
                if let spotlight {
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .stroke(Theme.accent.opacity(0.55), lineWidth: 1.5)
                        .frame(width: spotlight.width + 14, height: spotlight.height + 12)
                        .position(x: spotlight.midX, y: spotlight.midY)
                }
            }
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var placedCard: some View {
        if step == .finished {
            VStack(spacing: 0) {
                Spacer(minLength: Self.topInset)
                card
                Spacer(minLength: Self.bottomInset)
            }
        } else if let spotlight, spotlight.midY < size.height * 0.5 {
            VStack(spacing: 0) {
                Color.clear.frame(height: spotlight.maxY + Self.gap)
                card
                Spacer(minLength: Self.bottomInset)
            }
        } else if let spotlight {
            VStack(spacing: 0) {
                Spacer(minLength: Self.topInset)
                card
                Color.clear.frame(height: max(size.height - spotlight.minY + Self.gap, Self.bottomInset))
            }
        } else {
            VStack(spacing: 0) {
                Spacer(minLength: Self.topInset)
                card
                Spacer().frame(height: Self.bottomInset)
            }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(step.title)
                .appFont(Typography.passageTitle)
                .foregroundStyle(Theme.inkBright)

            Text(step.body)
                .appFont(Typography.callout)
                .foregroundStyle(Theme.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            footer
                .padding(.top, Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.xl)
        .cardSurface()
        .padding(.horizontal, Spacing.lg)
        .shadow(color: .black.opacity(0.16), radius: 18, y: 6)
    }

    @ViewBuilder
    private var footer: some View {
        if step == .finished {
            Button(action: onFinish) {
                Text("Start for real")
                    .appFont(Typography.button)
                    .foregroundStyle(Theme.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(Theme.accent, in: Capsule(style: .continuous))
                    .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(.haptic)
        } else {
            HStack(spacing: Spacing.md) {
                dots
                Spacer(minLength: Spacing.md)
                Button(action: onSkip) {
                    Text("Skip")
                        .appFont(Typography.label)
                        .tracking(0.5)
                        .foregroundStyle(Theme.muted)
                        .padding(.vertical, Spacing.xs)
                        .padding(.leading, Spacing.md)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.haptic)
            }
        }
    }

    private var dots: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(TourStep.allCases.dropLast(), id: \.rawValue) { entry in
                Circle()
                    .fill(entry == step ? Theme.accent : Theme.accentMuted)
                    .frame(width: 6, height: 6)
            }
        }
    }
}
