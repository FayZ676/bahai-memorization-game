import SwiftUI

enum RecitationBarMenu {
    case hideCounts
}

struct RecitationBar: View {
    let voice: VoiceRecitationController
    let canHideWords: Bool
    @Binding var micDeniedAlert: Bool
    let onStart: () -> Void
    let onHideWords: (Int) -> Void
    @Binding var hideCount: Int
    @Binding var openMenu: RecitationBarMenu?
    let hint: SessionHint

    @State private var hintHeight: CGFloat = 0
    @State private var standingMessage = ""

    private static let settle = Animation.easeInOut(duration: 0.22)
    private static let hideCounts = [2, 4, 6, 8, 10]
    private static let buttonHeight: CGFloat = 46
    private static let labelFont = Typography.body.weight(.medium)
    private static let optionDiameter: CGFloat = 44

    var body: some View {
        HStack(spacing: Spacing.sm) {
            hideButton
            reciteButton
        }
        .overlay(alignment: .top) {
            HintBubble(text: standingMessage)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { hintHeight = $0 }
                .offset(y: -hintHeight)
                .opacity(hint.message == nil ? 0 : 1)
                .scaleEffect(hint.message == nil ? 0.94 : 1, anchor: .bottom)
                .animation(Self.settle, value: hint.message)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
        .animation(Self.settle, value: voice.state)
        .onChange(of: hint.message) { _, message in
            guard let message else { return }
            standingMessage = message
        }
    }

    private var hideButton: some View {
        let open = openMenu == .hideCounts
        return HStack(spacing: Spacing.sm) {
            Image(systemName: "text.word.spacing")
                .appIcon(15)
            Text("Hide \(hideCount)")
                .appFont(Self.labelFont)
                .contentTransition(.numericText())
        }
        .foregroundStyle(open ? Theme.accent : (canHideWords ? Theme.muted : Theme.disabled))
        .frame(maxWidth: .infinity)
        .frame(height: Self.buttonHeight)
        .background(open ? Theme.accent.opacity(0.1) : .clear, in: Capsule())
        .contentShape(Capsule())
        .onTapGesture {
            Feedback.tap()
            guard openMenu == nil else { return closeMenu() }
            guard canHideWords else {
                return hint.show("Every word is already hidden.")
            }
            onHideWords(hideCount)
        }
        .onLongPressGesture(minimumDuration: 0.18) {
            Feedback.hide()
            hint.dismiss()
            openMenu = .hideCounts
        }
        .accessibilityElement()
        .accessibilityLabel("Hide words")
        .accessibilityValue("\(hideCount) at a time")
        .accessibilityHint("Double tap to hide \(hideCount) words in the marked paragraph. Touch and hold to choose how many.")
        .accessibilityAddTraits(.isButton)
        .overlay(alignment: .top) {
            BarPopUp(isOpen: open, width: Self.optionDiameter + 2 * Spacing.xxs) {
                countOptions
            }
            .offset(y: -Spacing.sm)
        }
        .animation(Self.settle, value: hideCount)
    }

    private var countOptions: some View {
        ForEach(Self.hideCounts.reversed(), id: \.self) { count in
            menuOption(selected: count == hideCount) {
                hideCount = count
            } label: {
                Text("\(count)")
                    .appFont(Typography.button)
            }
        }
    }

    private func menuOption<Label: View>(
        selected: Bool,
        choose: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button {
            choose()
            closeMenu()
        } label: {
            label()
                .foregroundStyle(selected ? Theme.accent : Theme.navIcon)
                .frame(width: Self.optionDiameter, height: Self.optionDiameter)
                .background(selected ? Theme.accent.opacity(0.18) : .clear, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.haptic)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func closeMenu() {
        openMenu = nil
    }

    private var reciteButton: some View {
        HStack(spacing: Spacing.sm) {
            reciteIcon
            Text(reciteLabel)
                .appFont(Self.labelFont)
        }
        .foregroundStyle(isUnavailable ? Theme.disabled : Theme.accent)
        .frame(maxWidth: .infinity)
        .frame(height: Self.buttonHeight)
        .background(isUnavailable ? Theme.bg : Theme.accent.opacity(0.1), in: Capsule())
        .contentShape(Capsule())
        .onTapGesture {
            Feedback.tap()
            guard openMenu == nil else { return closeMenu() }
            tapToSpeak()
        }
        .accessibilityElement()
        .accessibilityLabel("Recite aloud")
        .accessibilityHint("Tap the page to stop.")
        .accessibilityAddTraits(.isButton)
    }

    private func tapToSpeak() {
        switch voice.state {
        case .listening: voice.stop()
        case .micDenied: micDeniedAlert = true
        case .idle, .failed: onStart()
        case .preparingModel: break
        }
    }

    private var isActive: Bool {
        voice.state == .listening
    }

    @ViewBuilder
    private var reciteIcon: some View {
        if voice.state == .preparingModel {
            ProgressView()
                .controlSize(.small)
                .tint(Theme.accent)
        } else {
            Image(systemName: symbolName)
                .appIcon(15)
                .contentTransition(.symbolEffect(.replace.offUp))
                .symbolEffect(
                    .variableColor.iterative.dimInactiveLayers,
                    options: .repeat(.continuous),
                    isActive: isActive
                )
        }
    }

    private var reciteLabel: String {
        isActive ? "Listening" : "Recite"
    }

    private var symbolName: String {
        if isActive { return "waveform" }
        return isUnavailable ? "mic.slash" : "mic"
    }

    private var isUnavailable: Bool {
        voice.state == .micDenied
    }
}

private struct BarPopUp<Options: View>: View {
    let isOpen: Bool
    let width: CGFloat
    @ViewBuilder let options: Options

    @State private var height: CGFloat = 0

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            options
        }
        .padding(Spacing.xxs)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.09), radius: 12, y: 4)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .frame(width: width)
        .offset(y: -height)
        .opacity(isOpen ? 1 : 0)
        .scaleEffect(isOpen ? 1 : 0.8, anchor: .bottom)
        .allowsHitTesting(isOpen)
        .animation(.snappy(duration: 0.26, extraBounce: 0.1), value: isOpen)
    }
}
