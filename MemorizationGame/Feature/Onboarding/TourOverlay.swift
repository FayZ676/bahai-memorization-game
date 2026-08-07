import SwiftUI

struct TourOverlay: View {
    let step: TourStep
    let isPromptVisible: Bool
    let onSkip: () -> Void
    let onDismissPrompt: () -> Void
    let onShowPrompt: () -> Void
    let onFinish: () -> Void

    private var isPrompting: Bool { isPromptVisible }

    var body: some View {
        ZStack {
            if isPrompting {
                scrim.transition(.opacity)
                card.transition(.opacity)
            } else {
                helpButton.transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .animation(Motion.standard, value: step)
        .animation(Motion.standard, value: isPromptVisible)
    }

    private var scrim: some View {
        Rectangle()
            .fill(Theme.bg.opacity(0.88))
            .ignoresSafeArea()
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
            primaryButton("Start for real", action: onFinish)
        } else {
            VStack(spacing: Spacing.md) {
                primaryButton("Try it", action: onDismissPrompt)
                progressRow
            }
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .appFont(Typography.button)
                .foregroundStyle(Theme.bg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(Theme.accent, in: Capsule(style: .continuous))
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.haptic)
    }

    private var progressRow: some View {
        HStack(spacing: Spacing.md) {
            dots
            Spacer(minLength: Spacing.md)
            Button(action: onSkip) {
                Text("Skip Walkthrough")
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

    private var dots: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(TourStep.allCases.dropLast(), id: \.rawValue) { entry in
                Circle()
                    .fill(entry == step ? Theme.accent : Theme.accentMuted)
                    .frame(width: 6, height: 6)
            }
        }
    }

    private var helpButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: onShowPrompt) {
                    Image(systemName: "questionmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.bg)
                        .frame(width: 44, height: 44)
                        .background(Theme.accent, in: Circle())
                        .contentShape(Circle())
                        .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
                }
                .buttonStyle(.haptic)
            }
        }
        .padding(.trailing, Spacing.lg)
        .padding(.bottom, Spacing.md)
    }
}
