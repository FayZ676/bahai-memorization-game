import SwiftUI

struct SessionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm: SessionViewModel
    @State private var voice = VoiceRecitationController()
    @State private var started = false
    @State private var showingMicDenied = false
    @State private var scrubbing = false
    @State private var recitedWords: Set<Int> = []
    @State private var missedWords: Set<Int> = []
    @State private var missShakes = 0
    @State private var missFlashIndex: Int?
    @State private var wordFrames: [Int: CGRect] = [:]
    @State private var paintTargetHidden: Bool?
    @State private var painting = false
    @State private var scrollPosition = ScrollPosition()
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollableHeight: CGFloat = 0
    let passage: Passage
    private let store: AppStore

    init(passage: Passage, store: AppStore) {
        self.passage = passage
        self.store = store
        _vm = State(initialValue: SessionViewModel(passage: passage, store: store))
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                ScreenHeader(title: passage.title, onBack: { dismiss() }) {
                    if vm.current != nil { optionsMenu }
                }
                if vm.current != nil {
                    progressRow
                    readingArea
                    bottomBar
                } else {
                    Spacer()
                    emptyQueue
                    Spacer()
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .task {
            guard !started else { return }
            started = true
            vm.start()
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
            guard let card = vm.current else { return }
            voice.updateHiddenIndices(remainingHiddenIndices(of: card))
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

    private func remainingHiddenIndices(of card: Reviewable) -> [Int] {
        card.hiddenWords
            .filter { !recitedWords.contains($0) && !missedWords.contains($0) }
            .sorted()
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
                Text(vm.sectionLabel)
                    .font(Typography.micro)
                    .tracking(1.8)
                    .foregroundStyle(Theme.muted)
                Spacer()
                if vm.canMerge {
                    mergeButton
                }
            }
            heatBar
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 16)
        .animation(.easeInOut(duration: 0.22), value: vm.canMerge)
    }

    private var mergeButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.28)) { vm.merge() }
        } label: {
            Text("MERGE")
                .font(Typography.micro)
                .tracking(1.8)
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 11)
                .padding(.vertical, 3)
                .background(Capsule().stroke(Theme.accent.opacity(0.55), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.haptic)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    private var heatBar: some View {
        GeometryReader { geo in
            let heats = vm.sectionHeats
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
                    Text("Tap or glide over words to show or hide")
                        .font(Typography.micro)
                        .foregroundStyle(Theme.faint)
                        .padding(.top, 20)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: geo.size.height - 44, alignment: .topLeading)
                .padding(.horizontal, 30)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
            .scrollIndicators(.hidden)
        .scrollDisabled(painting)
        .scrollPosition($scrollPosition)
        .onScrollGeometryChange(for: ScrollGeometry.self) { $0 } action: { _, geometry in
            scrollOffset = geometry.contentOffset.y + geometry.contentInsets.top
            scrollableHeight = geometry.contentSize.height - geometry.containerSize.height
        }
        .overlay(alignment: .trailing) {
            if scrollableHeight > 1 {
                scrollRail(viewportHeight: geo.size.height)
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard !painting else { return }
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
        let words = card.words
        return VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(card.paragraphs.enumerated()), id: \.offset) { _, range in
                FlowLayout(spacing: 7, lineSpacing: 12) {
                    ForEach(range, id: \.self) { idx in
                        let expected = voice.nextExpectedIndex == idx
                        WordView(
                            token: String(words[idx]),
                            hidden: vm.isHidden(idx),
                            expected: expected,
                            recited: recitedWords.contains(idx),
                            missed: missedWords.contains(idx),
                            missFlashing: missFlashIndex == idx
                        )
                            .font(Typography.recite)
                            .modifier(ShakeEffect(shakes: missFlashIndex == idx ? CGFloat(missShakes) : 0))
                            .onGeometryChange(for: CGRect.self) { proxy in
                                proxy.frame(in: .named("scripture"))
                            } action: { frame in
                                wordFrames[idx] = frame
                            }
                    }
                }
            }
        }
        .coordinateSpace(name: "scripture")
        .contentShape(Rectangle())
        .allowsHitTesting(!vm.wordsRevealed)
        .simultaneousGesture(
            SpatialTapGesture(coordinateSpace: .named("scripture"))
                .onEnded { value in
                    guard !painting, let idx = wordIndex(at: value.location) else { return }
                    withAnimation(Motion.toggle) { vm.toggleWord(idx) }
                }
        )
        .simultaneousGesture(paintGesture)
    }

    private func scrollRail(viewportHeight: CGFloat) -> some View {
        let railHeight = max(viewportHeight - 44, 60)
        let thumbHeight = max(44, railHeight * railHeight / (railHeight + scrollableHeight))
        let travel = railHeight - thumbHeight
        let fraction = min(max(scrollOffset / scrollableHeight, 0), 1)
        return Capsule()
            .fill(Theme.faint.opacity(0.45))
            .frame(width: 2, height: thumbHeight)
            .offset(y: travel * fraction)
            .frame(width: 2, height: railHeight, alignment: .top)
        .frame(width: 28, height: railHeight)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard travel > 0 else { return }
                    let target = min(max((value.location.y - thumbHeight / 2) / travel, 0), 1)
                    scrollPosition.scrollTo(y: target * scrollableHeight)
                }
        )
    }

    private var paintGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("scripture")))
            .onChanged { value in
                guard case .second(true, let drag) = value else { return }
                if !painting {
                    painting = true
                    Feedback.flip()
                }
                guard let drag else { return }
                paint(at: drag.startLocation)
                paint(at: drag.location)
            }
            .onEnded { _ in
                paintTargetHidden = nil
                Task {
                    try? await Task.sleep(for: .milliseconds(80))
                    painting = false
                }
            }
    }

    private func paint(at location: CGPoint) {
        guard let idx = wordIndex(at: location) else { return }
        let target = paintTargetHidden ?? !vm.isHidden(idx)
        paintTargetHidden = target
        guard vm.isHidden(idx) != target else { return }
        withAnimation(Motion.toggle) { vm.toggleWord(idx) }
    }

    private func wordIndex(at location: CGPoint) -> Int? {
        let count = vm.current?.words.count ?? 0
        return wordFrames.first { idx, frame in
            idx < count && frame.insetBy(dx: -3.5, dy: -6).contains(location)
        }?.key
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            if voice.isListening {
                heardRow
            }
            if micVisible {
                micButton
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .padding(.bottom, 12)
        .animation(.easeInOut(duration: 0.2), value: micVisible)
        .animation(.easeInOut(duration: 0.2), value: voice.isListening)
    }

    private var micVisible: Bool {
        voice.isListening || !(vm.current?.hiddenWords.isEmpty ?? true)
    }

    private var heardRow: some View {
        HStack(spacing: 7) {
            if voice.isSettling {
                ProgressView()
                    .controlSize(.mini)
                    .tint(Theme.muted)
            }
            Text(heardLabel)
                .font(Typography.micro)
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
                vm.endPeek()
                var remaining = remainingHiddenIndices(of: card)
                if remaining.isEmpty {
                    recitedWords = []
                    missedWords = []
                    remaining = card.hiddenWords.sorted()
                }
                Task {
                    await voice.start(
                        words: card.words.map(String.init),
                        hiddenIndices: remaining
                    )
                }
            case .preparingModel:
                break
            }
        } label: {
            micIcon
                .frame(width: 56, height: 56)
                .background(micFill, in: Circle())
                .overlay(Circle().stroke(micStroke, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.haptic)
        .animation(.easeInOut(duration: 0.18), value: voice.state)
    }

    private var optionsMenu: some View {
        Menu {
            Button(vm.isPeeking ? "Unpeek" : "Peek") { vm.togglePeek() }
            Button("Hide All Words") {
                vm.setAllWords(hidden: true)
            }
            Button("Show All Words") { vm.setAllWords(hidden: false) }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.navIcon)
        }
        .buttonStyle(.icon)
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
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .symbolEffect(.pulse, options: .repeating)
        case .micDenied:
            Image(systemName: "mic.slash")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Theme.muted.opacity(0.5))
        case .idle, .failed:
            Image(systemName: "mic")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Theme.navIcon)
        }
    }

    private var micFill: Color {
        voice.state == .listening ? Theme.accent.opacity(0.18) : Theme.surface
    }

    private var micStroke: Color {
        voice.state == .listening ? Theme.accent.opacity(0.7) : Theme.hairline
    }

    private var emptyQueue: some View {
        Text("Nothing to review yet.")
            .font(Typography.subtitle)
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
                    .foregroundStyle(Theme.ink)
                    .opacity(hidden ? 0 : 1)
                    .blur(radius: hidden ? 2 : 0)
                    .overlay(alignment: .bottom) {
                        reciteLine.opacity(showLine ? 1 : 0)
                    }
            }
            if !p.trail.isEmpty { Text(p.trail).foregroundStyle(Theme.ink) }
        }
        .background {
            if let highlight {
                RoundedRectangle(cornerRadius: Radius.word, style: .continuous)
                    .fill(highlight)
                    .padding(.horizontal, -5)
                    .padding(.vertical, -3)
            }
        }
        .scaleEffect(pulsing ? 1.15 : 1)
        .animation(Motion.fade, value: hidden)
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

    // Once a word has faded, a slim line its own width cues the recitation.
    private var showLine: Bool { hidden || expected }

    private var reciteLine: some View {
        RoundedRectangle(cornerRadius: Radius.line, style: .continuous)
            .fill(lineColor)
            .frame(height: 2)
            .offset(y: 3)
    }

    private var lineColor: Color {
        if missFlashing || missed { return Theme.warn }
        if recited || expected { return Theme.accent }
        return Theme.muted
    }

    private var highlight: Color? {
        if pulsing { return Theme.accent.opacity(0.16) }
        if missFlashing { return Theme.warn.opacity(0.2) }
        if expected { return Theme.accent.opacity(0.12) }
        return nil
    }
}

private struct DailyGoalToast: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text("Daily goal complete")
                    .font(Typography.label)
                    .foregroundStyle(Theme.ink)
                Text("Today's practice is in — streak secured.")
                    .font(Typography.micro)
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule(style: .continuous)
                .fill(Theme.rowBg)
                .overlay(Capsule(style: .continuous).stroke(Theme.gold.opacity(0.5), lineWidth: 1))
        )
    }
}
