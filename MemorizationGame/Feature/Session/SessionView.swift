import StoreKit
import SwiftUI

struct SessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fontScale) private var fontScale
    @Environment(\.displayScale) private var displayScale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.tour) private var tour
    @Environment(\.requestReview) private var requestReview
    @State private var vm: SessionViewModel
    @State private var voice = VoiceRecitationController()
    @State private var started = false
    @State private var showingMicDenied = false
    @State private var openBarMenu: RecitationBarMenu?
    @State private var highlights = RecitationHighlights()
    @State private var painting = WordPainting()
    @State private var hint = SessionHint()
    @State private var scroll = PageScroll()
    @State private var pageCache = PageCache()
    @State private var textOrigin = PageOrigin()
    @State private var readingPosition = ScrollPosition(edge: .top)
    @State private var armedParagraph: Int?
    @State private var startWord = 0
    @State private var controlsHeight: CGFloat = 0
    @State private var headerHeight: CGFloat = 0
    @State private var chromeCleared = false
    @State private var headerCollapsed = false
    @State private var showingFullText = false
    @State private var showingEdit = false
    @State private var showingReportIssue = false
    @State private var showingFeedback = false
    let passage: Passage
    private let store: AppStore

    private static let pageTopMargin: CGFloat = 18
    private static let followThreshold: CGFloat = 0.7
    private static let railSamples = 48

    init(passage: Passage, store: AppStore) {
        self.passage = passage
        self.store = store
        _vm = State(initialValue: SessionViewModel(passage: passage, store: store))
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                if let current = vm.passage {
                    GeometryReader { geo in
                        let metrics = ReadingMetrics(width: geo.size.width, fontScale: fontScale, dynamicType: dynamicTypeSize)
                        let layout = pageCache.layout(
                            for: current,
                            width: geo.size.width - metrics.textMargin * 2,
                            metrics: metrics,
                            displayScale: displayScale
                        )
                        page(current, layout: layout, metrics: metrics, size: geo.size)
                            .clipped()
                            .overlay(alignment: .bottom) {
                                LinearGradient(colors: [Theme.bg.opacity(0), Theme.bg], startPoint: .top, endPoint: .bottom)
                                    .frame(height: controlsHeight / 2 + Spacing.lg)
                                    .allowsHitTesting(false)
                                    .opacity(isFocused ? 0 : 1)
                                    .animation(Motion.focus, value: isFocused)
                            }
                            .overlay {
                                if openBarMenu != nil {
                                    Color.clear
                                        .contentShape(Rectangle())
                                        .onTapGesture { openBarMenu = nil }
                                }
                            }
                            .overlay(alignment: .bottom) {
                                controls(current, layout: layout)
                                    .opacity(isFocused ? 0 : 1)
                                    .allowsHitTesting(!isFocused)
                                    .animation(Motion.focus, value: isFocused)
                            }
                    }
                } else {
                    Spacer()
                    emptyQueue
                    Spacer()
                }
            }
            .overlay(alignment: .top) { header }
            .overlay {
                if isFocused { stopSurface }
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
        .navigationDestination(isPresented: $showingReportIssue) {
            ContactView(purpose: .reportIssue)
        }
        .navigationDestination(isPresented: $showingFeedback) {
            ContactView(purpose: .feedback)
        }
        .onChange(of: showingEdit) { _, isEditing in
            guard !isEditing else { return }
            stopRecitation()
            highlights.clear()
        }
        .task {
            guard !started else { return }
            started = true
            voice.onWordsMatched = { registerRecited($0) }
            voice.onMiss = { registerMiss($0) }
            voice.onWordShown = { showMissedWord($0) }
            voice.onCompleted = { completeRecitation() }
            voice.prepare()
            #if DEBUG
            if ProcessInfo.processInfo.environment["SHOT_RECITING"] == "1" {
                try? await Task.sleep(for: .seconds(3))
                stageRecitationForCapture()
            }
            #endif
        }
        .onChange(of: vm.passage?.hiddenWords) {
            guard let current = vm.passage else { return }
            voice.updateHiddenIndices(highlights.unattempted(in: current, from: startWord))
        }
        .onChange(of: isFocused) { _, focused in
            chromeCleared = false
            withAnimation(Motion.focus) { headerCollapsed = focused }
            guard focused else { return }
            Task {
                try? await Task.sleep(for: .seconds(Motion.focusDuration))
                chromeCleared = isFocused
            }
        }
        .onDisappear { voice.stop() }
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
                }
            }
            .padding(.top, 10)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: store.justEarned)
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

    private func page(_ current: Passage, layout: PageLayout, metrics: ReadingMetrics, size: CGSize) -> some View {
        ScrollView {
            PageContent(
                passage: current,
                layout: layout,
                metrics: metrics,
                scroll: scroll,
                topInset: topInset,
                bottomInset: controlsHeight + Spacing.xxl,
                cascading: vm.cascading,
                highlights: highlights,
                isReciting: isReciting,
                isFocused: isFocused,
                cursor: recitationCursor,
                fixedStart: isReciting ? layout.paragraphIndex(containing: startWord) : armedParagraph,
                textOrigin: textOrigin,
                onMarker: { tapMarker($0, layout: layout) },
                onTapWord: { point in
                    guard !painting.isActive, let idx = layout.wordIndex(at: point) else { return }
                    toggleWord(idx)
                },
                onPaint: paintGesture(layout)
            )
        }
        .scrollIndicators(.hidden)
        .scrollDisabled(painting.isActive)
        .scrollPosition($readingPosition)
        .scrollTargetBehavior(ParagraphSnap(tops: layout.paragraphs.map(\.frame.minY), isActive: !isFocused))
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, top in
            scroll.update(top: top)
        }
        .onScrollPhaseChange { _, phase in
            if phase == .interacting { armedParagraph = nil }
        }
        .onAppear { scroll.viewportHeight = size.height }
        .onChange(of: size.height) { _, height in scroll.viewportHeight = height }
        .onChange(of: recitationCursor) { _, index in
            guard isReciting else { return }
            follow(index, layout: layout)
        }
    }

    private func controls(_ current: Passage, layout: PageLayout) -> some View {
        VStack(spacing: Spacing.xxs) {
            RecitationBar(
                voice: voice,
                canHideWords: !vm.everyWordHidden,
                micDeniedAlert: $showingMicDenied,
                onStart: { startRecitation(layout: layout) },
                onHideWords: { count in
                    let words = Set(layout.paragraphs[focusedParagraph(layout)].words)
                    guard vm.hideRandomWords(count, among: words) else {
                        return hint.show("Every word in this paragraph is already hidden.")
                    }
                    tour?.complete(.hideMany, onlyIfCurrent: true)
                },
                hideCount: Binding(
                    get: { vm.randomHideCount },
                    set: { vm.randomHideCount = $0 }
                ),
                openMenu: $openBarMenu,
                hint: hint
            )
            HeatRail(
                density: layout.density(of: current.hiddenWords, samples: Self.railSamples),
                pageHeight: topInset + layout.size.height,
                scroll: scroll,
                onSeek: { fraction, settled in seek(to: fraction, layout: layout, settled: settled) }
            )
            .padding(.horizontal, Spacing.lg)
        }
        .padding(.top, Spacing.xxs)
        .padding(.bottom, Spacing.sm)
        .background {
            RoundedRectangle(cornerRadius: Radius.panel, style: .continuous)
                .fill(Theme.raised)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.panel, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 18, y: 6)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.xs)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { controlsHeight = $0 }
    }

    private func celebrate(thenDismiss: @escaping () -> Void) {
        Feedback.sessionComplete()
        Task {
            try? await Task.sleep(for: .seconds(3))
            thenDismiss()
        }
    }

    private var currentTitle: String {
        vm.passage?.title ?? passage.title
    }

    #if DEBUG
    private func stageRecitationForCapture() {
        guard let current = vm.passage else { return }
        let hidden = current.hiddenWords.sorted()
        guard !hidden.isEmpty else { return }
        let spoken = Array(hidden.prefix((hidden.count + 1) / 2))
        highlights.recite(spoken)
        voice.stageListeningForCapture(cursor: hidden.dropFirst(spoken.count).first)
    }
    #endif

    private var topInset: CGFloat {
        Self.pageTopMargin + (headerCollapsed ? 0 : headerHeight)
    }

    private var isReciting: Bool {
        voice.isListening
    }

    private var isFocused: Bool {
        voice.isListening || voice.state == .preparingModel
    }

    private var recitationCursor: Int? {
        isReciting && chromeCleared ? voice.cursorIndex : nil
    }

    private var header: some View {
        ScreenHeader(title: currentTitle, onBack: { dismiss() }, onTitleTap: { showingFullText = true }) {
            if vm.passage != nil { optionsMenu }
        }
        .background(Theme.bg)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
        .opacity(isFocused ? 0 : 1)
        .allowsHitTesting(!isFocused)
        .animation(Motion.focus, value: isFocused)
    }

    private var stopSurface: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
                Feedback.tap()
                stopRecitation()
            }
            .accessibilityElement()
            .accessibilityLabel("Stop reciting")
            .accessibilityAddTraits(.isButton)
    }

    private func registerRecited(_ indices: [Int]) {
        RecitationTrace.emit("ui", "recited \(indices)")
        highlights.recite(indices)
        tour?.complete(.recite)
    }

    private func registerMiss(_ index: Int) {
        RecitationTrace.emit("ui", "miss \(index)")
        withAnimation(.linear(duration: 0.3)) { highlights.miss(index) }
        Feedback.recitationMiss()
        tour?.complete(.recite)
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            withAnimation(.easeOut(duration: 0.3)) { highlights.stopFlashing(index) }
        }
    }

    private func showMissedWord(_ index: Int) {
        RecitationTrace.emit("ui", "shown \(index)")
        guard vm.isMarked(index) else { return }
        withAnimation(Motion.toggle) { vm.toggleWord(index) }
    }

    private func completeRecitation() {
        RecitationTrace.emit("ui", "recitation complete")
        Feedback.sessionComplete()
        withAnimation(.easeInOut(duration: 0.3)) { highlights.clear() }
    }

    private func focusedParagraph(_ layout: PageLayout) -> Int {
        let tolerance = (layout.wordFrames.first?.height ?? 0) * 0.6
        return armedParagraph
            ?? layout.paragraphIndex(atTop: scroll.top, tolerance: tolerance)
            ?? 0
    }

    private func startRecitation(layout: PageLayout) {
        beginRecitation(at: focusedParagraph(layout), layout: layout)
    }

    private func beginRecitation(at paragraph: Int, layout: PageLayout) {
        guard let current = vm.passage, layout.paragraphs.indices.contains(paragraph) else { return }
        let start = layout.paragraphs[paragraph].words.lowerBound
        startWord = start
        var remaining = highlights.unattempted(in: current, from: start)
        if remaining.isEmpty {
            highlights.clear()
            remaining = current.recitableIndices(from: start)
        }
        guard !remaining.isEmpty else { return }
        scrollToParagraph(paragraph, layout: layout)
        Feedback.prepareRecitation()
        Task {
            await voice.start(words: current.words.map(String.init), hiddenIndices: remaining, from: start)
        }
    }

    private func stopRecitation() {
        if isFocused { voice.stop() }
    }

    private func tapMarker(_ paragraph: Int, layout: PageLayout) {
        tour?.complete(.startAnywhere, onlyIfCurrent: true)
        armedParagraph = paragraph
        scrollToParagraph(paragraph, layout: layout)
    }

    private func scrollToParagraph(_ paragraph: Int, layout: PageLayout) {
        let target = min(layout.paragraphs[paragraph].frame.minY, maxScrollTop(layout))
        withAnimation(.easeInOut(duration: 0.4)) {
            readingPosition.scrollTo(y: max(target, 0))
        }
    }

    private func seek(to fraction: CGFloat, layout: PageLayout, settled: Bool) {
        tour?.complete(.startAnywhere, onlyIfCurrent: true)
        armedParagraph = nil
        let pageHeight = topInset + layout.size.height
        var target = min(max(fraction * pageHeight - scroll.viewportHeight / 2, 0), maxScrollTop(layout))
        guard settled else {
            readingPosition.scrollTo(y: target)
            return
        }
        let reach = scroll.viewportHeight * 0.3
        if let nearest = layout.paragraphs.map(\.frame.minY)
            .filter({ $0 <= maxScrollTop(layout) + 1 })
            .min(by: { abs($0 - target) < abs($1 - target) }),
           abs(nearest - target) <= reach {
            target = nearest
        }
        withAnimation(.easeInOut(duration: 0.3)) {
            readingPosition.scrollTo(y: target)
        }
    }

    private func maxScrollTop(_ layout: PageLayout) -> CGFloat {
        let content = topInset + layout.size.height + PageContent.tipHeight + controlsHeight + Spacing.xxl
        return max(content - scroll.viewportHeight, 0)
    }

    private func follow(_ index: Int?, layout: PageLayout) {
        guard let index, layout.wordFrames.indices.contains(index) else { return }
        let frame = layout.wordFrames[index]
        let onScreen = topInset + frame.minY - scroll.top
        let comfortable = onScreen >= 0 && onScreen + frame.height <= scroll.viewportHeight * Self.followThreshold
        guard !comfortable else { return }
        let target = max(topInset + frame.minY - frame.height, 0)
        withAnimation(.easeInOut(duration: 0.35)) {
            readingPosition.scrollTo(y: min(target, maxScrollTop(layout)))
        }
    }

    private func paintGesture(_ layout: PageLayout) -> PaintRecognizer {
        PaintRecognizer(
            onBegan: { location in
                painting.begin()
                Feedback.flip()
                paint(at: location, layout: layout)
            },
            onMoved: { location in
                guard painting.isActive else { return }
                paint(at: location, layout: layout)
            },
            onEnded: {
                painting.end()
                Task {
                    try? await Task.sleep(for: .milliseconds(80))
                    painting.settle()
                }
            }
        )
    }

    private func paint(at location: CGPoint, layout: PageLayout) {
        let point = CGPoint(x: location.x - textOrigin.global.x, y: location.y - textOrigin.global.y)
        guard let idx = layout.wordIndex(at: point) else { return }
        guard painting.shouldToggle(vm.isMarked(idx)) else { return }
        toggleWord(idx)
    }

    private func toggleWord(_ idx: Int) {
        withAnimation(Motion.toggle) { vm.toggleWord(idx) }
        tour?.complete(.hideWord, onlyIfCurrent: true)
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

private struct PageContent: View {
    let passage: Passage
    let layout: PageLayout
    let metrics: ReadingMetrics
    let scroll: PageScroll
    let topInset: CGFloat
    let bottomInset: CGFloat
    let cascading: Bool
    let highlights: RecitationHighlights
    let isReciting: Bool
    let isFocused: Bool
    let cursor: Int?
    let fixedStart: Int?
    let textOrigin: PageOrigin
    let onMarker: (Int) -> Void
    let onTapWord: (CGPoint) -> Void
    let onPaint: PaintRecognizer

    static let tipHeight: CGFloat = 40

    var body: some View {
        let drawnBand = (scroll.drawnRange.lowerBound - topInset)...(scroll.drawnRange.upperBound - topInset)
        let drawn = layout.paragraphIndices(near: drawnBand)
        ZStack(alignment: .topLeading) {
            Color.clear
                .frame(height: topInset + layout.size.height + Self.tipHeight + bottomInset)
                .frame(maxWidth: .infinity)
            ForEach(drawn, id: \.self) { index in
                paragraph(index)
                    .offset(x: metrics.textMargin, y: topInset + layout.paragraphs[index].frame.minY)
            }
            MarkerColumn(
                layout: layout,
                drawn: drawn,
                scroll: scroll,
                fixedStart: fixedStart,
                topInset: topInset,
                margin: metrics.textMargin,
                onTap: onMarker
            )
            .opacity(isFocused ? 0 : 1)
            .allowsHitTesting(!isFocused)
            .animation(Motion.focus, value: isFocused)
            RecitationCursor(target: cursorTarget)
                .offset(x: metrics.textMargin, y: topInset)
            InfoNote(Typography.micro, color: Theme.faint) {
                Text("Tap and glide over words to show or hide them")
                    .appFont(Typography.micro)
                    .foregroundStyle(Theme.faint)
            }
            .offset(x: metrics.textMargin, y: topInset + layout.size.height + 20)
            .opacity(isFocused ? 0 : 1)
            .animation(Motion.focus, value: isFocused)
        }
        .onGeometryChange(for: CGPoint.self) { proxy in
            proxy.frame(in: .global).origin
        } action: { origin in
            textOrigin.global = CGPoint(x: origin.x + metrics.textMargin, y: origin.y + topInset)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            SpatialTapGesture()
                .onEnded { value in
                    onTapWord(CGPoint(x: value.location.x - metrics.textMargin, y: value.location.y - topInset))
                }
        )
        .gesture(onPaint)
    }

    private var cursorTarget: CGRect? {
        guard isReciting, let cursor, layout.wordFrames.indices.contains(cursor) else { return nil }
        return layout.wordFrames[cursor]
    }

    private func paragraph(_ index: Int) -> some View {
        let paragraph = layout.paragraphs[index]
        let words = passage.words
        return PlacedParagraph(
            frames: paragraph.words.map { layout.wordFrames[$0].offsetBy(dx: 0, dy: -paragraph.frame.minY) },
            size: paragraph.frame.size
        ) {
            ForEach(paragraph.words, id: \.self) { idx in
                WordView(
                    token: String(words[idx]),
                    concealed: isFocused && passage.hiddenWords.contains(idx) && !highlights.recited.contains(idx),
                    dimmed: !isFocused && passage.hiddenWords.contains(idx),
                    recited: highlights.recited.contains(idx),
                    missFlashing: highlights.isFlashing(idx),
                    staggerDelay: cascading ? Motion.cascadeDelay(idx, of: words.count) : 0
                )
                .font(Font(layout.font))
                .modifier(ShakeEffect(shakes: highlights.shakeAmount(at: idx)))
            }
        }
    }
}

private struct MarkerColumn: View {
    let layout: PageLayout
    let drawn: [Int]
    let scroll: PageScroll
    let fixedStart: Int?
    let topInset: CGFloat
    let margin: CGFloat
    let onTap: (Int) -> Void

    var body: some View {
        let tolerance = (layout.wordFrames.first?.height ?? 0) * 0.6
        let start = fixedStart ?? layout.paragraphIndex(atTop: scroll.top, tolerance: tolerance)
        let lineHeight = layout.wordFrames.first?.height ?? 0
        ForEach(drawn, id: \.self) { index in
            ParagraphMarker(isStart: index == start) { onTap(index) }
                .offset(
                    x: (margin - 30) / 2,
                    y: topInset + layout.paragraphs[index].frame.minY + (lineHeight - 30) / 2
                )
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
