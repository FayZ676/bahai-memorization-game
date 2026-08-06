import SwiftUI

struct SessionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm: SessionViewModel
    @State private var voice = VoiceRecitationController()
    @State private var started = false
    @State private var showingMicDenied = false
    @State private var scrubbing = false
    @State private var barWidth: CGFloat = 0
    @State private var recitedWords: Set<Int> = []
    @State private var missedWords: Set<Int> = []
    @State private var missShakes = 0
    @State private var missFlashIndex: Int?
    @State private var wordFrames: [Int: CGRect] = [:]
    @State private var paintTargetHidden: Bool?
    @State private var painting = false
    @State private var showingFullText = false
    @State private var showingEdit = false
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
                ScreenHeader(title: currentTitle, onBack: { dismiss() }, onTitleTap: { showingFullText = true }) {
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
        .completesTourStep(.openPassage)
        .navigationDestination(isPresented: $showingFullText) {
            PassageTextView(passage: passage, store: store)
        }
        .navigationDestination(isPresented: $showingEdit) {
            ImportView(editing: passage, store: store)
        }
        .onChange(of: showingEdit) { _, isEditing in
            guard !isEditing else { return }
            vm.start()
        }
        .task {
            guard !started else { return }
            started = true
            vm.start()
            voice.onWordsMatched = { registerRecited($0) }
            voice.onMiss = { registerMiss($0, movedOn: $1) }
            voice.onCompleted = { completeChunk() }
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
            Group {
                if let earned = store.justEarned {
                    AchievementToast(achievement: earned)
                } else if store.dailyGoalReached {
                    DailyGoalToast()
                }
            }
            .padding(.top, 10)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: store.dailyGoalReached)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: store.justEarned)
        .onChange(of: store.dailyGoalReached) { _, reached in
            guard reached else { return }
            Feedback.sessionComplete()
            Task {
                try? await Task.sleep(for: .seconds(3))
                store.dailyGoalReached = false
            }
        }
        .onChange(of: store.justEarned) { _, earned in
            guard earned != nil else { return }
            Feedback.sessionComplete()
            Task {
                try? await Task.sleep(for: .seconds(3))
                store.justEarned = nil
            }
        }
    }

    private var currentTitle: String {
        store.passages.first { $0.id == passage.id }?.title ?? passage.title
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

    private func completeChunk() {
        Feedback.sessionComplete()
        withAnimation(.easeInOut(duration: 0.3)) {
            recitedWords = []
            missedWords = []
        }
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
                    .appFont(Typography.micro)
                    .tracking(0.5)
                    .foregroundStyle(Theme.muted)
                Spacer()
                if vm.canMerge {
                    mergeButton
                }
            }
            heatBar
        }
        .padding(.horizontal, 26)
        .padding(.top, Spacing.headerGap)
        .padding(.bottom, 16)
        .animation(.easeInOut(duration: 0.22), value: vm.canMerge)
    }

    private var mergeButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.28)) { vm.merge() }
        } label: {
            MergeChip()
        }
        .buttonStyle(.haptic)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    private var heatBar: some View {
        let weights = vm.sectionWeights
        return ProgressBar(
            heats: vm.sectionHeats,
            weights: weights,
            animated: false,
            highlight: vm.step,
            completion: vm.hiddenFraction,
            barHeight: scrubbing ? 12 : 6
        )
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !scrubbing {
                        withAnimation(.easeOut(duration: 0.16)) { scrubbing = true }
                    }
                    withAnimation(.easeInOut(duration: 0.18)) {
                        vm.scrub(to: Self.segmentIndex(at: value.location.x, width: barWidth, weights: weights))
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.2)) { scrubbing = false }
                }
        )
        .onPreferenceChange(ProgressBarWidth.self) { barWidth = $0 }
        .frame(height: 20)
        .animation(.easeOut(duration: 0.14), value: vm.step)
    }

    private static func segmentIndex(at x: CGFloat, width: CGFloat, weights: [Int]) -> Int {
        let fractions = ProgressBar.displayFractions(weights: weights, count: weights.count)
        var edge: CGFloat = 0
        for (i, fraction) in fractions.enumerated() {
            edge += width * CGFloat(fraction)
            if x < edge { return i }
        }
        return max(weights.count - 1, 0)
    }

    // MARK: Reading

    private var readingArea: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let card = vm.current {
                        scripture(for: card)
                    }
                    InfoNote(Typography.micro, color: Theme.faint) {
                        Text("Tap and glide over words to show or hide them")
                            .appFont(Typography.micro)
                            .foregroundStyle(Theme.faint)
                    }
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
                            missFlashing: missFlashIndex == idx,
                            staggerDelay: vm.cascading ? Motion.cascadeDelay(idx, of: words.count) : 0
                        )
                            .appFont(Typography.recite)
                            .modifier(ShakeEffect(shakes: missFlashIndex == idx ? CGFloat(missShakes) : 0))
                            .onGeometryChange(for: CGRect.self) { proxy in
                                proxy.frame(in: .global)
                            } action: { frame in
                                wordFrames[idx] = frame
                            }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .allowsHitTesting(!vm.wordsRevealed)
        .simultaneousGesture(
            SpatialTapGesture(coordinateSpace: .global)
                .onEnded { value in
                    guard !painting, let idx = wordIndex(at: value.location) else { return }
                    withAnimation(Motion.toggle) { vm.toggleWord(idx) }
                }
        )
        .gesture(PaintRecognizer(
            onBegan: { location in
                guard !vm.wordsRevealed else { return }
                painting = true
                Feedback.flip()
                paint(at: location)
            },
            onMoved: { location in
                guard painting else { return }
                paint(at: location)
            },
            onEnded: {
                paintTargetHidden = nil
                Task {
                    try? await Task.sleep(for: .milliseconds(80))
                    painting = false
                }
            }
        ))
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
            if micVisible {
                micButton
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
            if voice.isListening {
                heardRow
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
                .appFont(Typography.micro)
                .foregroundStyle(Theme.faint)
                .lineLimit(1)
                .truncationMode(.head)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 26)
        .padding(.top, 8)
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
                Feedback.prepareRecitation()
                Task {
                    await voice.start(
                        words: card.words.map(String.init),
                        contextText: card.expectedText,
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
            Button("Edit", systemImage: "pencil") { showingEdit = true }
            Section("Just for Now") {
                Button(
                    vm.isPeeking ? "Stop Peeking" : "Peek at Hidden Words",
                    systemImage: "eyeglasses"
                ) { vm.togglePeek() }
            }
            Section("Change What's Hidden") {
                Button("Hide Every Word", systemImage: "eye.slash") {
                    vm.setAllWords(hidden: true)
                }
                Button("Show Every Word", systemImage: "eye") { vm.setAllWords(hidden: false) }
            }
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
            Image(systemName: "waveform")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .symbolEffect(.variableColor.iterative.dimInactiveLayers, options: .repeat(.continuous))
                .transition(.symbolEffect(.drawOn))
        case .idle, .failed, .micDenied:
            Image(systemName: micSymbol)
                .font(.system(size: 21, weight: .regular))
                .foregroundStyle(micTint)
                .contentTransition(.symbolEffect(.replace.magic(fallback: .replace.offUp)))
                .transition(.opacity)
        }
    }

    private var micSymbol: String {
        voice.state == .micDenied ? "mic.slash" : "mic"
    }

    private var micTint: Color {
        voice.state == .micDenied ? Theme.muted.opacity(0.5) : Theme.navIcon
    }

    private var micFill: Color {
        voice.state == .listening ? Theme.accent.opacity(0.18) : Theme.surface
    }

    private var micStroke: Color {
        voice.state == .listening ? Theme.accent.opacity(0.7) : Theme.hairline
    }

    private var emptyQueue: some View {
        Text("Nothing to review yet.")
            .appFont(Typography.subtitle)
            .foregroundStyle(Theme.muted)
            .multilineTextAlignment(.center)
    }
}

private struct PaintRecognizer: UIGestureRecognizerRepresentable {
    let onBegan: (CGPoint) -> Void
    let onMoved: (CGPoint) -> Void
    let onEnded: () -> Void

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = 0.3
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .began: onBegan(recognizer.location(in: nil))
        case .changed: onMoved(recognizer.location(in: nil))
        case .ended, .cancelled, .failed: onEnded()
        default: break
        }
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

private struct AchievementToast: View {
    let achievement: Achievement

    private var detail: String {
        guard let group = AchievementCatalog.group(containing: achievement) else {
            return achievement.title
        }
        return "\(achievement.title) · \(group.title)"
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "\(achievement.symbol).fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text("Achievement earned")
                    .appFont(Typography.label)
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .appFont(Typography.micro)
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

private struct DailyGoalToast: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text("Daily goal complete")
                    .appFont(Typography.label)
                    .foregroundStyle(Theme.ink)
                Text("Today's practice is in — streak secured.")
                    .appFont(Typography.micro)
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
