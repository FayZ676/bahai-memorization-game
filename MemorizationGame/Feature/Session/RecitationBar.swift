import SwiftUI

struct RecitationBar: View {
    let voice: VoiceRecitationController
    let hasHiddenWords: Bool
    let canHideWords: Bool
    let isConcealing: Bool
    @Binding var micDeniedAlert: Bool
    let onStart: () -> Void
    let onPeek: () -> Void
    let onHideWords: (Int) -> Void
    @Binding var hideCount: Int
    @Binding var showingCounts: Bool
    let hint: SessionHint

    @State private var hintHeight: CGFloat = 0
    @State private var standingMessage = ""
    @State private var countsHeight: CGFloat = 0

    private static let settle = Animation.easeInOut(duration: 0.22)
    private static let halo: CGFloat = 10
    private static let hideCounts = [2, 4, 6, 8, 10]
    private static let sideDiameter: CGFloat = 54
    private static let countDiameter: CGFloat = 44
    private static let countsReveal = Animation.snappy(duration: 0.26, extraBounce: 0.1)

    var body: some View {
        HStack(alignment: .bottom, spacing: -Self.halo) {
            hideButton
            micButton
            peekButton
        }
        .overlay(alignment: .topLeading) {
            countOptions
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { countsHeight = $0 }
                .frame(width: Self.sideDiameter + 2 * Self.halo)
                .offset(y: -countsHeight)
                .opacity(showingCounts ? 1 : 0)
                .scaleEffect(showingCounts ? 1 : 0.8, anchor: .bottom)
                .allowsHitTesting(showingCounts)
                .animation(Self.countsReveal, value: showingCounts)
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
        .animation(Self.settle, value: isConcealing)
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
        !hasHiddenWords && !isConcealing
    }

    private var peekButton: some View {
        sideButton(
            symbol: isConcealing ? "eye.slash" : "eye",
            on: isConcealing,
            dimmed: peekDisabled,
            action: {
                closeCounts()
                peekDisabled ? hint.show("Nothing to peek. Try hiding a word first.") : onPeek()
            }
        )
    }

    private var hideButton: some View {
        sideFace(symbol: "text.word.spacing", on: showingCounts, dimmed: !canHideWords)
            .onTapGesture {
                Feedback.tap()
                guard !showingCounts else { return closeCounts() }
                guard canHideWords else {
                    return hint.show("Every word is already hidden.")
                }
                onHideWords(hideCount)
            }
            .onLongPressGesture(minimumDuration: 0.18) {
                Feedback.hide()
                hint.dismiss()
                showingCounts = true
            }
    }

    private var countOptions: some View {
        VStack(spacing: Spacing.xxs) {
            ForEach(Self.hideCounts.reversed(), id: \.self) { count in
                Button {
                    hideCount = count
                    closeCounts()
                } label: {
                    Text("\(count)")
                        .appFont(Typography.button)
                        .foregroundStyle(count == hideCount ? Theme.accent : Theme.navIcon)
                        .frame(width: Self.countDiameter, height: Self.countDiameter)
                        .background(count == hideCount ? Theme.accent.opacity(0.18) : .clear, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.haptic)
            }
        }
        .padding(Spacing.xxs)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.09), radius: 12, y: 4)
    }

    private func closeCounts() {
        showingCounts = false
    }

    private func sideButton(
        symbol: String,
        on: Bool,
        dimmed: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            sideFace(symbol: symbol, on: on, dimmed: dimmed)
        }
        .buttonStyle(.haptic)
    }

    private func sideFace(symbol: String, on: Bool, dimmed: Bool) -> some View {
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
            closeCounts()
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
