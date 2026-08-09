import SwiftUI

struct RecitationBar: View {
    let voice: VoiceRecitationController
    let hasHiddenWords: Bool
    @Binding var micDeniedAlert: Bool
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if isVisible {
                micButton
                    .padding(.top, Spacing.md)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
            if let status = statusLabel {
                statusRow(status)
            }
        }
        .padding(.bottom, Spacing.md)
        .animation(.easeInOut(duration: 0.2), value: isVisible)
        .animation(.easeInOut(duration: 0.2), value: voice.isListening)
    }

    private var isVisible: Bool {
        voice.isListening || hasHiddenWords
    }

    private func statusRow(_ label: String) -> some View {
        HStack(spacing: 7) {
            if voice.isSettling {
                ProgressView()
                    .controlSize(.mini)
                    .tint(Theme.muted)
            }
            Text(label)
                .appFont(Typography.micro)
                .foregroundStyle(Theme.faint)
                .lineLimit(1)
                .truncationMode(.head)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 26)
        .padding(.top, Spacing.sm)
        .animation(.easeInOut(duration: 0.15), value: voice.isSettling)
    }

    private var statusLabel: String? {
        switch voice.state {
        case .preparingModel:
            guard let progress = voice.downloadProgress else { return "Preparing…" }
            return "Downloading speech model… \(Int(progress * 100))%"
        case .failed:
            return "Couldn't start listening. Tap to try again."
        case .listening:
            if voice.isSettling { return "Checking…" }
            return voice.heardText.isEmpty ? "Listening…" : voice.heardText
        case .idle, .micDenied:
            return nil
        }
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
        .animation(.easeInOut(duration: 0.18), value: voice.state)
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
            Image(systemName: idleSymbol)
                .font(.system(size: 21, weight: .regular))
                .foregroundStyle(denied ? Theme.muted.opacity(0.5) : Theme.navIcon)
                .contentTransition(.symbolEffect(.replace.magic(fallback: .replace.offUp)))
                .transition(.opacity)
        }
    }

    private var denied: Bool {
        voice.state == .micDenied
    }

    private var idleSymbol: String {
        switch voice.state {
        case .micDenied: "mic.slash"
        case .failed: "arrow.clockwise"
        default: "mic"
        }
    }

    private var fill: Color {
        voice.state == .listening ? Theme.accent.opacity(0.18) : Theme.surface
    }

    private var stroke: Color {
        voice.state == .listening ? Theme.accent.opacity(0.7) : Theme.hairline
    }
}
