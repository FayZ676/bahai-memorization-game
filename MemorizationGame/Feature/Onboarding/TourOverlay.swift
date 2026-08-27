import SwiftUI

struct TourOverlay: View {
    @Environment(\.fontScale) private var fontScale
    let step: TourStep
    let isPromptVisible: Bool
    let canGoBack: Bool
    let canGoForward: Bool
    let onBack: () -> Void
    let onForward: () -> Void
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
            .contentShape(Rectangle())
            .onTapGesture(perform: Feedback.tapping(onDismissPrompt))
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            titleRow

            step.body(scale: fontScale)
                .appFont(Typography.callout)
                .foregroundStyle(Theme.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if !step.notes.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    ForEach(step.notes) { note in
                        InfoNote(Typography.footnote, color: Theme.faint, symbol: note.symbol) {
                            Text(note.text)
                                .italic()
                                .appFont(Typography.footnote)
                                .foregroundStyle(Theme.faint)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            footer
                .padding(.top, Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.xl)
        .cardSurface()
        .padding(.horizontal, Spacing.lg)
        .shadow(color: .black.opacity(0.16), radius: 18, y: 6)
    }

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text(step.title)
                .appFont(Typography.passageTitle)
                .foregroundStyle(Theme.inkBright)

            Spacer(minLength: Spacing.sm)

            Text(stepCounter)
                .appFont(Typography.label)
                .tracking(0.5)
                .foregroundStyle(Theme.faint)
                .fixedSize()
        }
    }

    private var stepCounter: String {
        let index = TourStep.allCases.firstIndex(of: step) ?? 0
        return "\(index + 1)/\(TourStep.allCases.count)"
    }

    private var footer: some View {
        VStack(spacing: Spacing.md) {
            if step == .finished {
                primaryButton("Start for real", action: onFinish)
            } else {
                primaryButton("Try it", action: onDismissPrompt)
            }
            progressRow
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
        HStack(spacing: Spacing.xs) {
            if step != .finished {
                skipButton
            }
            Spacer(minLength: Spacing.sm)
            arrow("chevron.left", enabled: canGoBack, action: onBack)
            arrow("chevron.right", enabled: canGoForward, action: onForward)
        }
    }

    private func arrow(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(enabled ? Theme.muted : Theme.faint)
                .frame(width: 34, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.haptic)
        .disabled(!enabled)
    }

    private var skipButton: some View {
        Button(action: onSkip) {
            Text("Skip Walkthrough")
                .appFont(Typography.label)
                .tracking(0.5)
                .foregroundStyle(Theme.muted)
                .padding(.vertical, Spacing.xs)
                .padding(.trailing, Spacing.md)
                .contentShape(Rectangle())
        }
        .buttonStyle(.haptic)
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
