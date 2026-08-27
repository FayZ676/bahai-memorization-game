import StoreKit
import SwiftUI

struct SessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fontScale) private var fontScale
    @Environment(\.tour) private var tour
    @Environment(\.requestReview) private var requestReview
    @State private var vm: SessionViewModel
    @State private var voice = VoiceRecitationController()
    @State private var started = false
    @State private var showingMicDenied = false
    @State private var scrubbing = false
    @State private var rail = RailVisibility()
    @State private var showingHideCounts = false
    @State private var barBounds: CGRect = .zero
    @State private var highlights = RecitationHighlights()
    @State private var painting = WordPainting()
    @State private var hint = SessionHint()
    @State private var scriptureFrame: CGRect = .zero
    @State private var readingViewport: CGRect = .zero
    @State private var scrollRequest: ScrollRequest?
    @State private var readingPosition = ScrollPosition()
    @State private var wordFrames = WordFrames()
    @State private var scrollOffset = ScrollOffset()
    @State private var scrollReach = ScrollReach()
    @State private var departing: Departure?
    @State private var slide: CGFloat = 0
    @State private var showingFullText = false
    @State private var showingEdit = false
    @State private var showingReportIssue = false
    @State private var showingSpeechHistory = false
    @State private var showingFeedback = false
    @State private var recitingChunkID: UUID?
    let passage: Passage
    private let store: AppStore

    private static let followInsets = (top: CGFloat(56), bottom: CGFloat(120))
    private static let visibleInsets = (top: CGFloat(4), bottom: CGFloat(100))
    private static let followAnchor = UnitPoint(x: 0, y: 0.34)
    private static let followSettleDelays: [Duration] = [.milliseconds(140), .milliseconds(450)]
    private static let sectionSlide = Animation.smooth(duration: 0.62, extraBounce: 0)

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
                    GeometryReader { geo in
                        let metrics = ReadingMetrics(width: geo.size.width, fontScale: fontScale)
                        readingArea(metrics)
                        .overlay(alignment: .leading) {
                            if rail.isShowing {
                                progressRail(metrics)
                                    .transition(.move(edge: .leading).combined(with: .opacity))
                            }
                        }
                        .overlay {
                            if showingHideCounts {
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture { showingHideCounts = false }
                            }
                        }
                        .overlay(alignment: .bottom) {
                            RecitationBar(
                                voice: voice,
                                hasHiddenWords: !(vm.current?.hiddenWords.isEmpty ?? true),
                                canHideWords: !vm.everyWordHidden,
                                isConcealing: vm.concealing,
                                micDeniedAlert: $showingMicDenied,
                                onStart: startRecitation,
                                onPeek: {
                                    vm.toggleConcealment()
                                    tour?.complete(.peek, onlyIfCurrent: true)
                                },
                                onHideWords: { count in
                                    guard vm.hideRandomWords(count, among: visibleWordIndices) else {
                                        return hint.show("Every word in view is already hidden.")
                                    }
                                    tour?.complete(.hideMany, onlyIfCurrent: true)
                                },
                                hideCount: Binding(
                                    get: { vm.randomHideCount },
                                    set: { vm.randomHideCount = $0 }
                                ),
                                showingCounts: $showingHideCounts,
                                hint: hint
                            )
                        }
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
        .completesTourStep(.openPassage)
        .navigationDestination(isPresented: $showingFullText) {
            PassageTextView(passage: passage, store: store)
        }
        .navigationDestination(isPresented: $showingEdit) {
            ImportView(editing: passage, store: store)
        }
        .navigationDestination(isPresented: $showingSpeechHistory) {
            SpeechHistoryView()
        }
        .navigationDestination(isPresented: $showingReportIssue) {
            ContactView(purpose: .reportIssue)
        }
        .navigationDestination(isPresented: $showingFeedback) {
            ContactView(purpose: .feedback)
        }
        .onChange(of: showingEdit) { _, isEditing in
            guard !isEditing else { return }
            vm.start()
        }
        .task {
            guard !started else { return }
            started = true
            rail.stir()
            vm.start()
            voice.onWordsMatched = { registerRecited($0) }
            voice.onMiss = { registerMiss($0, movedOn: $1) }
            voice.onCompleted = { completeChunk() }
            voice.onAttemptFinished = { recordAttempt($0) }
            voice.prepare(for: vm.passageText)
            #if DEBUG
            if ProcessInfo.processInfo.environment["SHOT_RECITING"] == "1" {
                try? await Task.sleep(for: .seconds(3))
                stageRecitationForCapture()
            }
            #endif
        }
        .onChange(of: vm.step) {
            tour?.complete(.nextSection, onlyIfCurrent: true)
        }
        .onChange(of: tour?.step) { _, step in
            guard step == .nextSection, !vm.hasMultipleSections else { return }
            tour?.complete(.nextSection)
        }
        .onChange(of: vm.presentationEpoch) {
            voice.stop()
            highlights.clear()
            voice.prepare(for: vm.passageText)
        }
        .onChange(of: vm.current?.hiddenWords) {
            guard let card = vm.current else { return }
            voice.updateHiddenIndices(highlights.unattempted(in: card))
        }
        .onDisappear { voice.release() }
        .alert("Microphone Access Needed", isPresented: $showingMicDenied) {
            Button("Open Settings", action: Feedback.tapping {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            })
            Button("Cancel", role: .cancel, action: Feedback.tapping {})
        } message: {
            Text("Allow microphone access in Settings to practice by reciting.")
        }
        .overlay(alignment: .top) {
            Group {
                if let earned = store.justEarned {
                    Toast(
                        symbol: "\(earned.symbol).fill",
                        title: "Achievement earned",
                        detail: earned.title
                    )
                } else if store.dailyGoalReached {
                    Toast(
                        symbol: "sparkles",
                        title: "Daily goal complete",
                        detail: "Today's practice is in — streak secured."
                    )
                }
            }
            .padding(.top, 10)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: store.dailyGoalReached)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: store.justEarned)
        .onChange(of: store.dailyGoalReached) { _, reached in
            guard reached else { return }
            celebrate { store.dailyGoalReached = false }
        }
        .onChange(of: store.justEarned) { _, earned in
            guard earned != nil else { return }
            celebrate { store.justEarned = nil }
        }
        .onChange(of: store.passageJustMemorized) { _, memorized in
            guard memorized else { return }
            store.passageJustMemorized = false
            guard ReviewPrompt.shouldAsk(
                memorizedPassageCount: store.memorizedPassageIDs.count,
                settings: store.settings
            ) else { return }
            Task {
                try? await Task.sleep(for: ReviewPrompt.delayAfterCelebration)
                store.markReviewRequested()
                requestReview()
            }
        }
    }

    private func celebrate(thenDismiss: @escaping () -> Void) {
        Feedback.sessionComplete()
        Task {
            try? await Task.sleep(for: .seconds(3))
            thenDismiss()
        }
    }

    private var currentTitle: String {
        store.passages.first { $0.id == passage.id }?.title ?? passage.title
    }

    #if DEBUG
    private func stageRecitationForCapture() {
        guard let card = vm.current else { return }
        let hidden = card.hiddenWords.sorted()
        guard !hidden.isEmpty else { return }
        let spoken = Array(hidden.prefix((hidden.count + 1) / 2))
        highlights.recite(spoken)
        let words = card.words
        let cursor = hidden.dropFirst(spoken.count).first
        let spokenThrough = cursor ?? words.count
        let heard = words[max(0, spokenThrough - 7)..<spokenThrough]
            .map(String.init)
            .filter { $0.contains(where: \.isLetter) }
            .joined(separator: " ")
        voice.stageListeningForCapture(cursor: cursor, heard: heard)
    }
    #endif

    private func registerRecited(_ indices: [Int]) {
        RecitationTrace.emit("ui", "recited \(indices)")
        highlights.recite(indices)
        tour?.complete(.recite)
    }

    private var cursorTarget: CGRect? {
        guard voice.isListening,
              let index = voice.cursorIndex,
              let frame = wordFrames.frame(at: index),
              scriptureFrame != .zero else { return nil }
        return frame.offsetBy(dx: -scriptureFrame.minX, dy: -scriptureFrame.minY)
    }

    private func completeChunk() {
        RecitationTrace.emit("ui", "chunk complete")
        Feedback.sessionComplete()
        withAnimation(.easeInOut(duration: 0.3)) { highlights.clear() }
    }

    private func recordAttempt(_ draft: RecitationDraft) {
        guard let chunkID = recitingChunkID ?? vm.current?.id,
              let card = store.reviewables.first(where: { $0.id == chunkID }) else { return }
        RecitationLog.shared.record(
            draft.attempt(
                chunkID: chunkID,
                passageTitle: currentTitle,
                excerpt: card.words.prefix(6).joined(separator: " ")
            )
        )
        recitingChunkID = nil
    }

    private func registerMiss(_ index: Int, movedOn: Bool) {
        RecitationTrace.emit("ui", "miss \(index) movedOn=\(movedOn)")
        withAnimation(.linear(duration: 0.3)) { highlights.miss(index, movedOn: movedOn) }
        Feedback.recitationMiss()
        tour?.complete(.recite)
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            withAnimation(.easeOut(duration: 0.3)) { highlights.stopFlashing(index) }
        }
    }

    private func startRecitation() {
        guard let card = vm.current else { return }
        vm.conceal()
        var remaining = highlights.unattempted(in: card)
        if remaining.isEmpty {
            highlights.clear()
            remaining = card.recitableIndices
        }
        Feedback.prepareRecitation()
        recitingChunkID = card.id
        if let first = remaining.first {
            scrollRequest = ScrollRequest(index: first)
        }
        Task {
            await voice.start(
                words: card.words.map(String.init),
                contextText: card.expectedText,
                passageText: vm.passageText,
                hiddenIndices: remaining
            )
        }
    }

    private func progressRail(_ metrics: ReadingMetrics) -> some View {
        let weights = vm.sectionWeights
        return ProgressBar(
            heats: vm.sectionHeats,
            weights: weights,
            animated: false,
            highlight: vm.step,
            barHeight: scrubbing ? 8 : 4,
            axis: .vertical
        )
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    if !scrubbing {
                        withAnimation(.easeOut(duration: 0.16)) { scrubbing = true }
                    }
                    rail.hold()
                    withAnimation(.easeInOut(duration: 0.18)) {
                        vm.scrub(to: Self.segmentIndex(
                            at: value.location.y - barBounds.minY,
                            extent: barBounds.height,
                            weights: weights
                        ))
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.2)) { scrubbing = false }
                    rail.stir()
                }
        )
        .onPreferenceChange(ProgressBarBounds.self) { barBounds = $0 }
        .frame(width: metrics.railWidth)
        .padding(.leading, metrics.railInset)
        .padding(.top, Spacing.headerGap)
        .padding(.bottom, Spacing.sm)
        .animation(.easeOut(duration: 0.14), value: vm.step)
    }

    private static func segmentIndex(at distance: CGFloat, extent: CGFloat, weights: [Int]) -> Int {
        let fractions = ProgressBar.displayFractions(weights: weights, count: weights.count)
        var edge: CGFloat = 0
        for (i, fraction) in fractions.enumerated() {
            edge += extent * CGFloat(fraction)
            if distance < edge { return i }
        }
        return max(weights.count - 1, 0)
    }

    private func readingArea(_ metrics: ReadingMetrics) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                if let departing {
                    departingSection(departing, height: geo.size.height, metrics: metrics)
                }
                if let card = vm.current {
                    sectionScroll(card, viewportHeight: geo.size.height, metrics: metrics)
                        .id(card.id)
                        .offset(y: slide)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { frame in
                readingViewport = frame
            }
            .onChange(of: voice.cursorIndex) { _, index in
                guard voice.isListening else { return }
                follow(index)
            }
            .onChange(of: scrollRequest) { _, request in
                guard let request else { return }
                Task { await settleCursorInView(from: request.index) }
            }
            .onChange(of: voice.isListening) { _, listening in
                guard listening, let index = voice.cursorIndex else { return }
                follow(index, force: true)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func sectionScroll(_ card: Reviewable, viewportHeight: CGFloat, metrics: ReadingMetrics) -> some View {
        ScrollView {
            sectionBody(card, viewportHeight: viewportHeight, live: true, metrics: metrics)
        }
        .scrollIndicators(.hidden)
        .scrollDisabled(painting.isActive)
        .scrollPosition($readingPosition)
        .onScrollGeometryChange(for: ScrollReach.self) { geometry in
            ScrollReach(
                top: geometry.contentOffset.y + geometry.contentInsets.top,
                bottom: geometry.contentSize.height - geometry.contentOffset.y - geometry.containerSize.height
            )
        } action: { previous, reach in
            scrollOffset.y = reach.top
            scrollReach = reach
            if abs(reach.top - previous.top) > 0.5 { rail.stir() }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard !painting.isActive, departing == nil else { return }
                    guard abs(value.translation.height) > abs(value.translation.width) else { return }
                    if value.translation.height < 0, scrollReach.atBottom {
                        moveSection(forward: true)
                    } else if value.translation.height > 0, scrollReach.atTop {
                        moveSection(forward: false)
                    }
                }
        )
    }

    private func departingSection(_ departure: Departure, height: CGFloat, metrics: ReadingMetrics) -> some View {
        sectionBody(departure.card, viewportHeight: height, live: false, metrics: metrics)
            .offset(y: -departure.scrollTop)
            .frame(height: height, alignment: .topLeading)
            .clipped()
            .allowsHitTesting(false)
            .offset(y: slide - (departure.advancing ? height : -height))
    }

    private func sectionBody(_ card: Reviewable, viewportHeight: CGFloat, live: Bool, metrics: ReadingMetrics) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            scripture(for: card, live: live, metrics: metrics)
            InfoNote(Typography.micro, color: Theme.faint) {
                Text("Tap and glide over words to show or hide them")
                    .appFont(Typography.micro)
                    .foregroundStyle(Theme.faint)
            }
            .padding(.top, 20)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: viewportHeight - 64, alignment: .topLeading)
        .padding(.horizontal, metrics.textMargin)
        .padding(.top, 18)
        .padding(.bottom, 110)
    }

    private func moveSection(forward: Bool) {
        guard forward ? vm.canGoForward : vm.canGoBack, let card = vm.current else { return }
        let height = readingViewport.height
        departing = Departure(card: card, scrollTop: scrollOffset.y, advancing: forward)
        vm.skip(forward: forward)
        readingPosition.scrollTo(edge: .top)
        slide = forward ? height : -height
        DispatchQueue.main.async {
            withAnimation(Self.sectionSlide) {
                slide = 0
            } completion: {
                departing = nil
            }
        }
    }

    private var visibleWordIndices: Set<Int> {
        guard readingViewport != .zero, let card = vm.current else { return [] }
        let ceiling = readingViewport.minY + Self.visibleInsets.top
        let floor = readingViewport.maxY - Self.visibleInsets.bottom
        return Set(card.words.indices.filter { idx in
            guard let frame = wordFrames.frame(at: idx) else { return false }
            return frame.minY >= ceiling && frame.maxY <= floor
        })
    }

    private func follow(_ index: Int?, force: Bool = false) {
        guard let index,
              let frame = wordFrames.frame(at: index),
              readingViewport != .zero else { return }
        let ceiling = readingViewport.minY + Self.followInsets.top
        let floor = readingViewport.maxY - Self.followInsets.bottom
        guard force || frame.minY < ceiling || frame.maxY > floor else { return }
        let anchorY = readingViewport.minY + readingViewport.height * Self.followAnchor.y
        let target = max(scrollOffset.y + frame.minY - anchorY, 0)
        withAnimation(.easeInOut(duration: 0.35)) {
            readingPosition.scrollTo(y: target)
        }
    }

    private func settleCursorInView(from index: Int) async {
        follow(index, force: true)
        for delay in Self.followSettleDelays {
            try? await Task.sleep(for: delay)
            guard scrollRequest?.index == index else { return }
            follow(voice.isListening ? (voice.cursorIndex ?? index) : index, force: true)
        }
    }

    private func scripture(for card: Reviewable, live: Bool, metrics: ReadingMetrics) -> some View {
        let words = card.words
        return VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(card.paragraphs.enumerated()), id: \.offset) { _, range in
                FlowLayout(spacing: metrics.wordSpacing, lineSpacing: metrics.lineSpacing, justified: true, maxStretchPerGap: metrics.maxStretchPerGap) {
                    ForEach(range, id: \.self) { idx in
                        WordView(
                            token: String(words[idx]),
                            concealed: vm.concealing && card.hiddenWords.contains(idx),
                            recited: live && highlights.recited.contains(idx),
                            missed: live && highlights.missed.contains(idx),
                            missFlashing: live && highlights.isFlashing(idx),
                            staggerDelay: live && vm.cascading ? Motion.cascadeDelay(idx, of: words.count) : 0
                        )
                            .appFont(Typography.recite)
                            .modifier(ShakeEffect(shakes: live ? highlights.shakeAmount(at: idx) : 0))
                            .onGeometryChange(for: CGRect.self) { proxy in
                                proxy.frame(in: .global)
                            } action: { frame in
                                guard live else { return }
                                wordFrames.record(frame, at: idx)
                            }
                    }
                }
            }
        }
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { frame in
            guard live else { return }
            scriptureFrame = frame
        }
        .overlay(alignment: .topLeading) {
            if live {
                RecitationCursor(target: cursorTarget)
            }
        }
        .contentShape(Rectangle())
        .allowsHitTesting(live)
        .simultaneousGesture(
            SpatialTapGesture(coordinateSpace: .global)
                .onEnded { value in
                    guard !painting.isActive, let idx = wordIndex(at: value.location) else { return }
                    toggleWord(idx)
                }
        )
        .gesture(PaintRecognizer(
            onBegan: { location in
                painting.begin()
                Feedback.flip()
                paint(at: location)
            },
            onMoved: { location in
                guard painting.isActive else { return }
                paint(at: location)
            },
            onEnded: {
                painting.end()
                Task {
                    try? await Task.sleep(for: .milliseconds(80))
                    painting.settle()
                }
            }
        ))
    }

    private func paint(at location: CGPoint) {
        guard let idx = wordIndex(at: location) else { return }
        guard painting.shouldToggle(vm.isMarked(idx)) else { return }
        toggleWord(idx)
    }

    private func toggleWord(_ idx: Int) {
        withAnimation(Motion.toggle) { vm.toggleWord(idx) }
        tour?.complete(.hideWord, onlyIfCurrent: true)
    }

    private func wordIndex(at location: CGPoint) -> Int? {
        wordFrames.index(at: location, wordCount: vm.current?.words.count ?? 0)
    }

    private var optionsMenu: some View {
        Menu {
            Button(
                "Edit Passage",
                systemImage: "pencil",
                action: Feedback.tapping { showingEdit = true }
            )
            Section {
                Button(
                    "Hide Every Word",
                    systemImage: "text.page.slash",
                    action: Feedback.tapping {
                        guard !vm.everyWordHidden else {
                            return hint.show("Every word is already hidden.")
                        }
                        vm.setAllWords(hidden: true)
                    }
                )
                Button(
                    "Show Every Word",
                    systemImage: "text.page",
                    action: Feedback.tapping {
                        guard !vm.everyWordShowing else {
                            return hint.show("Every word is already showing.")
                        }
                        vm.setAllWords(hidden: false)
                    }
                )
            }
            Section {
                Button(
                    "Speech History",
                    systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    action: Feedback.tapping { showingSpeechHistory = true }
                )
                Button(
                    "Report Issue",
                    systemImage: "exclamationmark.bubble",
                    action: Feedback.tapping { showingReportIssue = true }
                )
                Button(
                    "Send Feedback",
                    systemImage: "paperplane",
                    action: Feedback.tapping { showingFeedback = true }
                )
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.navIcon)
        }
        .buttonStyle(.icon)
    }

    private var emptyQueue: some View {
        Text("Nothing to review yet.")
            .appFont(Typography.subtitle)
            .foregroundStyle(Theme.muted)
            .multilineTextAlignment(.center)
    }
}

private struct ReadingMetrics {
    let textMargin: CGFloat
    let railInset: CGFloat
    let railWidth: CGFloat
    let maxStretchPerGap: CGFloat
    let wordSpacing: CGFloat
    let lineSpacing: CGFloat

    init(width: CGFloat, fontScale: CGFloat) {
        let narrow = width < 390
        textMargin = narrow ? 30 : 42
        railInset = narrow ? 3 : 8
        railWidth = narrow ? 22 : 26
        maxStretchPerGap = (narrow ? 1.5 : 2.5) * fontScale
        wordSpacing = 7 * fontScale
        lineSpacing = 8 * fontScale
    }
}

private struct ScrollRequest: Equatable {
    let index: Int
    let issued = UUID()
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

private struct Toast: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .appIcon(16, weight: .semibold)
                .foregroundStyle(Theme.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
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

struct Departure {
    let card: Reviewable
    let scrollTop: CGFloat
    let advancing: Bool
}
