import SwiftUI

struct RecitationBar: View {
    let voice: VoiceRecitationController
    let hasHiddenWords: Bool
    let isPeeking: Bool
    @Binding var micDeniedAlert: Bool
    let onStart: () -> Void
    let onPeek: () -> Void
    let onToggleRail: () -> Void

    private static let settle = Animation.easeInOut(duration: 0.22)

    var body: some View {
        HStack(alignment: .bottom, spacing: -10) {
            railButton
            micButton
            peekButton
        }
        .padding(.bottom, Spacing.xxs)
        .animation(Self.settle, value: voice.state)
        .animation(Self.settle, value: isPeeking)
    }

    private var peekDisabled: Bool {
        !hasHiddenWords && !isPeeking
    }

    private var peekButton: some View {
        sideButton(
            symbol: isPeeking ? "eye.slash" : "eye",
            on: isPeeking,
            disabled: peekDisabled,
            action: onPeek
        )
    }

    private var railButton: some View {
        sideButton(
            symbol: "sidebar.squares.leading",
            on: false,
            disabled: false,
            action: onToggleRail
        )
    }

    private func sideButton(
        symbol: String,
        on: Bool,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(sideSymbolColor(on: on, disabled: disabled))
                .contentTransition(.symbolEffect(.replace.offUp))
                .frame(width: 54, height: 54)
                .background(on ? Theme.accent.opacity(0.18) : Theme.surface, in: Circle())
                .background(Theme.surface, in: Circle())
                .overlay(Circle().stroke(sideStroke(on: on, disabled: disabled), lineWidth: 1))
                .shadow(color: .black.opacity(0.05), radius: 7, y: 2)
                .padding(10)
                .contentShape(Circle())
        }
        .buttonStyle(.haptic)
        .disabled(disabled)
    }

    private func sideSymbolColor(on: Bool, disabled: Bool) -> Color {
        if on { return Theme.accent }
        return disabled ? Theme.muted.opacity(0.5) : Theme.navIcon
    }

    private func sideStroke(on: Bool, disabled: Bool) -> Color {
        if on { return Theme.accent.opacity(0.7) }
        return disabled ? Theme.hairline.opacity(0.6) : Theme.hairline
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
