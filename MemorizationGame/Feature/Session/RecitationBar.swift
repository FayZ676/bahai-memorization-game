import SwiftUI

struct RecitationBar: View {
    let voice: VoiceRecitationController
    let hasHiddenWords: Bool
    let isPeeking: Bool
    @Binding var micDeniedAlert: Bool
    let onStart: () -> Void
    let onPeek: () -> Void
    let onToggleRail: () -> Void

    @State private var hintShowing = false
    @State private var hintToken = 0

    private static let settle = Animation.easeInOut(duration: 0.22)
    private static let hintDwell = Duration.seconds(2.4)

    var body: some View {
        HStack(alignment: .bottom, spacing: -10) {
            railButton
            micButton
            peekButton
        }
        .padding(.bottom, Spacing.xxs)
        .animation(Self.settle, value: voice.state)
        .animation(Self.settle, value: isPeeking)
        .onChange(of: peekDisabled) { _, disabled in
            guard !disabled else { return }
            withAnimation(Self.settle) { hintShowing = false }
        }
    }

    private var peekDisabled: Bool {
        !hasHiddenWords && !isPeeking
    }

    private var peekButton: some View {
        sideButton(
            symbol: isPeeking ? "eye.slash" : "eye",
            on: isPeeking,
            dimmed: peekDisabled,
            action: { peekDisabled ? flashHint() : onPeek() }
        )
        .overlay(alignment: .top) {
            if hintShowing {
                hint
                    .offset(y: -34)
                    .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .bottom)))
            }
        }
    }

    private var hint: some View {
        Text("Nothing is hidden yet — tap words to hide them.")
            .appFont(Typography.micro)
            .foregroundStyle(Theme.muted)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: 190)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .fill(Theme.rowBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                            .stroke(Theme.hairline, lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
            .allowsHitTesting(false)
    }

    private func flashHint() {
        hintToken += 1
        let token = hintToken
        withAnimation(Self.settle) { hintShowing = true }
        Task {
            try? await Task.sleep(for: Self.hintDwell)
            guard token == hintToken else { return }
            withAnimation(Self.settle) { hintShowing = false }
        }
    }

    private var railButton: some View {
        sideButton(
            symbol: "sidebar.squares.leading",
            on: false,
            dimmed: false,
            action: onToggleRail
        )
    }

    private func sideButton(
        symbol: String,
        on: Bool,
        dimmed: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(sideSymbolColor(on: on, dimmed: dimmed))
                .contentTransition(.symbolEffect(.replace.offUp))
                .frame(width: 54, height: 54)
                .background(on ? Theme.accent.opacity(0.18) : Theme.surface, in: Circle())
                .background(Theme.surface, in: Circle())
                .overlay(Circle().stroke(sideStroke(on: on, dimmed: dimmed), lineWidth: 1))
                .shadow(color: .black.opacity(0.05), radius: 7, y: 2)
                .padding(10)
                .contentShape(Circle())
        }
        .buttonStyle(.haptic)
    }

    private func sideSymbolColor(on: Bool, dimmed: Bool) -> Color {
        if on { return Theme.accent }
        return dimmed ? Theme.muted.opacity(0.5) : Theme.navIcon
    }

    private func sideStroke(on: Bool, dimmed: Bool) -> Color {
        if on { return Theme.accent.opacity(0.7) }
        return dimmed ? Theme.hairline.opacity(0.6) : Theme.hairline
    }

    private var micButton: some View {
        Button {
            switch voice.state {
            case .listening: voice.stop()
            case .micDenied: micDeniedAlert = true
            case .idle, .failed: onStart()
            case .preparingModel: break
            }
        } label: {
            micIcon
                .frame(width: 68, height: 68)
                .background(fill, in: Circle())
                .background(Theme.surface, in: Circle())
                .overlay(Circle().stroke(stroke, lineWidth: 1))
                .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
                .padding(10)
                .contentShape(Circle())
        }
        .buttonStyle(.haptic)
    }

    @ViewBuilder
    private var micIcon: some View {
        if voice.state == .preparingModel {
            ProgressView()
                .controlSize(.small)
                .tint(Theme.muted)
        } else {
            Image(systemName: symbolName)
                .font(.system(size: 25, weight: voice.state == .listening ? .semibold : .regular))
                .foregroundStyle(symbolColor)
                .contentTransition(.symbolEffect(.replace.offUp))
                .symbolEffect(
                    .variableColor.iterative.dimInactiveLayers,
                    options: .repeat(.continuous),
                    isActive: voice.state == .listening
                )
        }
    }

    private var symbolName: String {
        if voice.state == .listening { return "waveform" }
        return isUnavailable ? "mic.slash" : "mic"
    }

    private var symbolColor: Color {
        if voice.state == .listening { return Theme.accent }
        return isUnavailable ? Theme.muted.opacity(0.5) : Theme.navIcon
    }

    private var isUnavailable: Bool {
        voice.state == .micDenied
    }

    private var fill: Color {
        if voice.state == .listening { return Theme.accent.opacity(0.18) }
        return Theme.surface
    }

    private var stroke: Color {
        if voice.state == .listening { return Theme.accent.opacity(0.7) }
        return isUnavailable ? Theme.hairline.opacity(0.6) : Theme.hairline
    }
}
