import SwiftUI

struct RecitationBar: View {
    let voice: VoiceRecitationController
    let hasHiddenWords: Bool
    let showsHint: Bool
    let isPeeking: Bool
    @Binding var micDeniedAlert: Bool
    let onStart: () -> Void
    let onPeek: () -> Void

    private static let settle = Animation.easeInOut(duration: 0.22)

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                peekButton
                micButton
                peekButton.hidden()
            }
            if showsHint {
                hint
            }
        }
        .padding(.bottom, Spacing.xxs)
        .animation(Self.settle, value: voice.state)
        .animation(Self.settle, value: showsHint)
        .animation(Self.settle, value: isDisabled)
        .animation(Self.settle, value: isPeeking)
    }

    private var peekDisabled: Bool {
        !hasHiddenWords && !isPeeking
    }

    private var peekButton: some View {
        Button(action: onPeek) {
            Image(systemName: "eyeglasses")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(peekSymbolColor)
                .frame(width: 46, height: 46)
                .background(peekFill, in: Circle())
                .background(Theme.surface, in: Circle())
                .overlay(Circle().stroke(peekStroke, lineWidth: 1))
                .shadow(color: .black.opacity(0.05), radius: 7, y: 2)
                .padding(10)
                .contentShape(Circle())
        }
        .buttonStyle(.haptic)
        .disabled(peekDisabled)
    }

    private var peekSymbolColor: Color {
        if isPeeking { return Theme.accent }
        return peekDisabled ? Theme.muted.opacity(0.5) : Theme.navIcon
    }

    private var peekFill: Color {
        isPeeking ? Theme.accent.opacity(0.18) : Theme.surface
    }

    private var peekStroke: Color {
        if isPeeking { return Theme.accent.opacity(0.7) }
        return peekDisabled ? Theme.hairline.opacity(0.6) : Theme.hairline
    }

    private var isDisabled: Bool {
        !hasHiddenWords && !voice.isListening
    }

    private var hint: some View {
        InfoNote(Typography.micro, color: Theme.faint) {
            Text("Hide a word to activate the mic.")
                .appFont(Typography.micro)
                .foregroundStyle(Theme.faint)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 26)
        .padding(.top, Spacing.xxs)
        .transition(.opacity)
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
        .disabled(isDisabled)
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
        voice.state == .micDenied || isDisabled
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
