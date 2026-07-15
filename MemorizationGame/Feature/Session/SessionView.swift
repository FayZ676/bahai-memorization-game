import SwiftUI

struct SessionRoute: Hashable {
    let passage: Passage
    let focusCardID: UUID
}

struct SessionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm: SessionViewModel
    @State private var voice = VoiceRecitationController()
    @State private var started = false
    @State private var showingAllOptions = false
    @State private var showingMicDenied = false
    @State private var scrubbing = false
    @State private var recitedWords: Set<Int> = []
    @State private var missedWords: Set<Int> = []
    @State private var missShakes = 0
    @State private var missFlashIndex: Int?
    let passage: Passage
    let focusCardID: UUID?
    private let store: AppStore

    init(passage: Passage, store: AppStore, focusCardID: UUID? = nil) {
        self.passage = passage
        self.store = store
        self.focusCardID = focusCardID
        _vm = State(initialValue: SessionViewModel(passage: passage, store: store))
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                ScreenHeader(title: passage.title, onBack: { dismiss() }) {
                    if vm.current != nil { micButton }
                }
                if vm.current != nil {
                    progressRow
                    readingArea
                    if voice.isListening {
                        heardRow
                    }
                } else {
                    Spacer()
                    emptyQueue
                    Spacer()
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .confirmationDialog("Words", isPresented: $showingAllOptions, titleVisibility: .hidden) {
            Button("Hide All Words") { vm.setAllWords(hidden: true) }
            Button("Show All Words") { vm.setAllWords(hidden: false) }
        }
        .task {
            guard !started else { return }
            started = true
            vm.start(focusing: focusCardID)
            voice.onWordsMatched = { registerRecited($0) }
            voice.onMiss = { registerMiss($0, movedOn: $1) }
            voice.onCompleted = { Feedback.sessionComplete() }
            voice.prewarm()
        }
        .onChange(of: vm.presentationEpoch) {
            voice.stop()
            recitedWords = []
            missedWords = []
        }
        .onChange(of: vm.current?.hiddenWords) {
            if voice.isListening { voice.stop() }
        }
        .onDisappear { voice.stop() }
        .alert("Microphone Access Needed", isPresented: $showingMicDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow microphone access in Settings to practice by reciting.")
        }
        .overlay(alignment: .top) {
            if store.dailyGoalReached {
                DailyGoalToast()
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: store.dailyGoalReached)
        .onChange(of: store.dailyGoalReached) { _, reached in
            guard reached else { return }
            Feedback.sessionComplete()
            Task {
                try? await Task.sleep(for: .seconds(3))
                store.dailyGoalReached = false
            }
        }
    }

    private func registerRecited(_ indices: [Int]) {
        recitedWords.formUnion(indices)
        Feedback.wordMatched()
    }

    private func registerMiss(_ index: Int, movedOn: Bool) {
        withAnimation(.linear(duration: 0.3)) { missShakes += 1 }
        if movedOn { missedWords.insert(index) }
        missFlashIndex = index
        Feedback.recitationMiss()
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            withAnimation(.easeOut(duration: 0.3)) {
                if missFlashIndex == index { missFlashIndex = nil }
            }
        }
    }

    // MARK: Progress

    private var progressRow: some View {
        VStack(spacing: 9) {
            HStack {
                Text("PASSAGE \(vm.progressNumber)")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(Theme.muted)
                Spacer()
                Text("\(vm.progressNumber) / \(vm.progressTotal)")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.5)
                    .foregroundStyle(Theme.faint)
                    .monospacedDigit()
            }
            heatBar
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 16)
    }

    private var heatBar: some View {
        GeometryReader { geo in
            let heats = vm.chunkHeats
            let count = max(heats.count, 1)
            let unit = geo.size.width / CGFloat(count)
            HeatStrip(heats: heats, animated: false, highlight: vm.step)
                .frame(height: scrubbing ? 12 : 6)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !scrubbing {
                            withAnimation(.easeOut(duration: 0.16)) { scrubbing = true }
                        }
                        withAnimation(.easeInOut(duration: 0.18)) {
                            vm.scrub(to: Int(value.location.x / unit))
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.easeOut(duration: 0.2)) { scrubbing = false }
                    }
            )
        }
        .frame(height: 20)
        .animation(.easeOut(duration: 0.14), value: vm.step)
    }

    // MARK: Reading

    private var readingArea: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let card = vm.current {
                        scripture(for: card)
                    }
                    Text(vm.isPracticing ? "Tap a word to show or hide it · hold for all" : "Tap to recite · swipe to change passage")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.faint)
                        .padding(.top, 20)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .topLeading)
                .padding(.horizontal, 30)
                .padding(.top, 8)
                .padding(.bottom, 36)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.32)) { vm.toggleMode() }
                }
                .onLongPressGesture(minimumDuration: 0.4) {
                    Feedback.flip()
                    showingAllOptions = true
                }
            }
            .scrollIndicators(.hidden)
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    if value.translation.width < 0, vm.canGoForward {
                        withAnimation(.easeInOut(duration: 0.28)) { vm.skip(forward: true) }
                    } else if value.translation.width > 0, vm.canGoBack {
                        withAnimation(.easeInOut(duration: 0.28)) { vm.skip(forward: false) }
                    }
                }
        )
        .fadeEdge(.top, height: 16)
        .fadeEdge(.bottom, height: 28)
        }
        .frame(maxHeight: .infinity)
    }

    private func scripture(for card: Reviewable) -> some View {
        FlowLayout(spacing: 7, lineSpacing: 12) {
            ForEach(Array(card.words.enumerated()), id: \.offset) { idx, word in
                let expected = voice.nextExpectedIndex == idx
                WordView(
                    token: String(word),
                    hidden: vm.isHidden(idx),
                    expected: expected,
                    recited: recitedWords.contains(idx),
                    missed: missedWords.contains(idx),
                    missFlashing: missFlashIndex == idx
                )
                    .font(.scripture(24))
                    .modifier(ShakeEffect(shakes: missFlashIndex == idx ? CGFloat(missShakes) : 0))
                    .contentShape(Rectangle())
                    .allowsHitTesting(vm.isPracticing)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.22)) { vm.toggleWord(idx) }
                    }
            }
        }
    }

    // MARK: Bottom bar

    private var heardRow: some View {
        HStack(spacing: 7) {
            if voice.isSettling {
                ProgressView()
                    .controlSize(.mini)
                    .tint(Theme.muted)
            }
            Text(heardLabel)
                .font(.system(size: 11))
                .foregroundStyle(Theme.faint)
                .lineLimit(1)
                .truncationMode(.head)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 26)
        .padding(.top, 6)
        .animation(.easeInOut(duration: 0.15), value: voice.isSettling)
    }

    private var heardLabel: String {
        if voice.isSettling { return "Checking…" }
        return voice.heardText.isEmpty ? "Listening…" : voice.heardText
    }

    private var micButton: some View {
        Button {
            switch voice.state {
            case .listening:
                voice.stop()
            case .micDenied:
                showingMicDenied = true
            case .idle, .failed:
                guard let card = vm.current else { return }
                recitedWords = []
                missedWords = []
                Task {
                    await voice.start(
                        words: card.words.map(String.init),
                        hiddenIndices: card.hiddenWords.sorted()
                    )
                }
            case .preparingModel:
                break
            }
        } label: {
            micIcon
                .frame(width: 38, height: 38)
                .background(micFill, in: Circle())
                .overlay(Circle().stroke(micStroke, lineWidth: 1))
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
            Image(systemName: "mic.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.emberHot)
                .symbolEffect(.pulse, options: .repeating)
        case .micDenied:
            Image(systemName: "mic.slash")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.muted.opacity(0.5))
        case .idle, .failed:
            Image(systemName: "mic")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.navIcon)
        }
    }

    private var micFill: Color {
        voice.state == .listening ? Theme.ember.opacity(0.28) : Theme.surface
    }

    private var micStroke: Color {
        voice.state == .listening ? Theme.emberHot.opacity(0.7) : Theme.hairline
    }

    private var emptyQueue: some View {
        Text("Nothing to review yet.")
            .font(.body)
            .foregroundStyle(Theme.muted)
            .multilineTextAlignment(.center)
    }
}

private struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 4 * sin(shakes * .pi * 3), y: 0))
    }
}

private struct WordView: View {
    let token: String
    let hidden: Bool
    let expected: Bool
    let recited: Bool
    let missed: Bool
    let missFlashing: Bool
    @State private var pulsing = false

    private var parts: (lead: String, core: String, trail: String) {
        let chars = Array(token)
        func isCore(_ c: Character) -> Bool { c.isLetter || c == "'" || c == "\u{2019}" }
        var i = 0
        while i < chars.count && !isCore(chars[i]) { i += 1 }
        var j = chars.count
        while j > i && !isCore(chars[j - 1]) { j -= 1 }
        return (
            String(chars[0..<i]),
            String(chars[i..<j]),
            String(chars[j..<chars.count])
        )
    }

    var body: some View {
        let p = parts
        HStack(spacing: 0) {
            if !p.lead.isEmpty { Text(p.lead).foregroundStyle(Theme.ink) }
            if !p.core.isEmpty {
                Text(p.core)
                    .foregroundStyle(hidden ? .clear : Theme.ink)
                    .overlay(alignment: .bottom) {
                        if hidden || expected {
                            underline
                        }
                    }
            }
            if !p.trail.isEmpty { Text(p.trail).foregroundStyle(Theme.ink) }
        }
        .background {
            if let highlight {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(highlight)
                    .padding(.horizontal, -5)
                    .padding(.vertical, -3)
            }
        }
        .scaleEffect(pulsing ? 1.18 : 1)
        .animation(.easeInOut(duration: 0.18), value: expected)
        .onChange(of: recited) { wasRecited, isRecited in
            guard isRecited, !wasRecited else { return }
            withAnimation(.easeOut(duration: 0.1)) { pulsing = true }
            Task {
                try? await Task.sleep(for: .milliseconds(110))
                withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) { pulsing = false }
            }
        }
    }

    private var highlight: Color? {
        if pulsing { return Theme.emberHot.opacity(0.3) }
        if missFlashing { return Theme.ember.opacity(0.26) }
        if expected { return Theme.accent.opacity(0.13) }
        return nil
    }

    private var underline: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(underlineColor)
            .frame(height: pulsing ? 4 : (expected ? 3 : 2))
            .offset(y: 2)
            .shadow(color: Theme.emberHot.opacity(pulsing ? 0.9 : 0), radius: 5)
            .phaseAnimator([1.0, 0.35]) { bar, phase in
                bar.opacity(expected && !missFlashing && !pulsing ? phase : 1)
            } animation: { _ in
                .easeInOut(duration: 0.6)
            }
    }

    private var underlineColor: Color {
        if missFlashing { return Theme.ember }
        if recited { return Theme.emberHot }
        if missed { return Theme.ember }
        if expected { return Theme.accent }
        return Theme.accent.opacity(0.5)
    }
}

private struct DailyGoalToast: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "flame.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.emberHot)
            VStack(alignment: .leading, spacing: 2) {
                Text("Daily goal complete")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Today's heat is full — streak secured.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule(style: .continuous)
                .fill(Theme.rowBg)
                .overlay(Capsule(style: .continuous).stroke(Theme.ember.opacity(0.5), lineWidth: 1))
                .shadow(color: Theme.ember.opacity(0.35), radius: 10)
        )
    }
}
