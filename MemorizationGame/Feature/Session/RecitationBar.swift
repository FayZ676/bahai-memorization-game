import SwiftUI

struct RecitationBar: View {
    let voice: VoiceRecitationController
    let hasHiddenWords: Bool
    let isPeeking: Bool
    @Binding var micDeniedAlert: Bool
    let onStart: () -> Void
    let onPeek: () -> Void
    let onToggleRail: () -> Void
    let hint: SessionHint

    @State private var hintHeight: CGFloat = 0
    @State private var standingMessage = ""

    private static let settle = Animation.easeInOut(duration: 0.22)
    private static let halo: CGFloat = 10

    var body: some View {
        HStack(alignment: .bottom, spacing: -Self.halo) {
            railButton
            micButton
            peekButton
        }
        .overlay(alignment: .top) {
            HintBubble(text: standingMessage)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { hintHeight = $0 }
                .offset(y: -hintHeight)
                .opacity(hint.message == nil ? 0 : 1)
                .scaleEffect(hint.message == nil ? 0.94 : 1, anchor: .bottom)
                .animation(Self.settle, value: hint.message)
        }
        .padding(.bottom, Spacing.xxs)
        .animation(Self.settle, value: voice.state)
        .animation(Self.settle, value: isPeeking)
        .onChange(of: hint.message) { _, message in
            guard let message else { return }
            standingMessage = message
        }
        .onChange(of: peekDisabled) { _, disabled in
            guard !disabled else { return }
            hint.dismiss()
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
            action: {
                peekDisabled ? hint.show("Nothing to peek. Try hiding a word first.") : onPeek()
            }
        )
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
                .padding(Self.halo)
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
                .padding(Self.halo)
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
