import SwiftUI

struct RecitationBar: View {
    let voice: VoiceRecitationController
    let hasHiddenWords: Bool
    @Binding var micDeniedAlert: Bool
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            micButton
                .padding(.top, Spacing.md)
            if voice.isListening {
                heardRow
            } else if !hasHiddenWords {
                hint
            }
        }
        .padding(.bottom, Spacing.md)
        .animation(.easeInOut(duration: 0.2), value: hasHiddenWords)
        .animation(.easeInOut(duration: 0.2), value: voice.isListening)
    }

    private var isDisabled: Bool {
        !hasHiddenWords && !voice.isListening
    }

    private var hint: some View {
        InfoNote(Typography.micro, color: Theme.faint) {
            Text("Hide a word to recite from memory")
                .appFont(Typography.micro)
                .foregroundStyle(Theme.faint)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 26)
        .padding(.top, Spacing.sm)
        .transition(.opacity)
    }

    private var heardRow: some View {
        Text(voice.heardText.isEmpty ? "Listening…" : voice.heardText)
            .appFont(Typography.micro)
            .foregroundStyle(Theme.faint)
            .lineLimit(1)
            .truncationMode(.head)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 26)
            .padding(.top, Spacing.sm)
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
                .frame(width: 56, height: 56)
                .background(fill, in: Circle())
                .overlay(Circle().stroke(stroke, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.haptic)
        .disabled(isDisabled)
        .animation(.easeInOut(duration: 0.18), value: voice.state)
        .animation(.easeInOut(duration: 0.18), value: isDisabled)
    }

    @ViewBuilder
    private var micIcon: some View {
        switch voice.state {
        case .preparingModel:
            ProgressView()
                .controlSize(.small)
                .tint(Theme.muted)
        case .listening:
            Image(systemName: "waveform")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .symbolEffect(.variableColor.iterative.dimInactiveLayers, options: .repeat(.continuous))
                .transition(.symbolEffect(.drawOn))
        case .idle, .failed, .micDenied:
            Image(systemName: denied ? "mic.slash" : "mic")
                .font(.system(size: 21, weight: .regular))
                .foregroundStyle(denied || isDisabled ? Theme.muted.opacity(0.5) : Theme.navIcon)
                .contentTransition(.symbolEffect(.replace.magic(fallback: .replace.offUp)))
                .transition(.opacity)
        }
    }

    private var denied: Bool {
        voice.state == .micDenied
    }

    private var fill: Color {
        if voice.state == .listening { return Theme.accent.opacity(0.18) }
        return isDisabled ? Theme.surface.opacity(0.5) : Theme.surface
    }

    private var stroke: Color {
        if voice.state == .listening { return Theme.accent.opacity(0.7) }
        return isDisabled ? Theme.hairline.opacity(0.6) : Theme.hairline
    }
}
