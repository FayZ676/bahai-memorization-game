import SwiftUI

struct SessionRoute: Hashable {
    let passage: Passage
    let focusCardID: UUID
}

struct SessionView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var vm: SessionViewModel
    @State private var voice = VoiceRecitationController()
    @State private var started = false
    @State private var showingOptions = false
    @State private var showingMicDenied = false
    @State private var scrubbing = false
    let passage: Passage
    let focusCardID: UUID?

    init(passage: Passage, focusCardID: UUID? = nil) {
        self.passage = passage
        self.focusCardID = focusCardID
        _vm = State(initialValue: SessionViewModel(passage: passage, store: AppStore()))
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                ScreenHeader(title: passage.title, onBack: { dismiss() }) {
                    if vm.isPracticing { micButton }
                }
                if vm.current != nil {
                    progressRow
                    readingArea
                    if vm.isPracticing {
                        bottomBar
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
        .sheet(isPresented: $showingOptions) {
            ChunkOptionsView(vm: vm)
                .environment(store)
        }
        .task {
            guard !started else { return }
            started = true
            vm = SessionViewModel(passage: passage, store: store)
            vm.start(focusing: focusCardID)
            voice.onFrontierAdvance = { revealThroughFrontier($0) }
        }
        .onChange(of: vm.presentationEpoch) { voice.stop() }
        .onChange(of: vm.isPracticing) {
            if !vm.isPracticing { voice.stop() }
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
            Text("Allow microphone access in Settings to reveal words by reciting them.")
        }
    }

    private func revealThroughFrontier(_ frontier: Int) {
        guard let card = vm.current else { return }
        let revealed = card.hiddenWords.filter { $0 <= frontier }.sorted()
        guard !revealed.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            revealed.forEach { vm.revealWord($0) }
        }
        Feedback.wordSpoken()
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
            ChunkHeatStrip(heats: heats, animated: false, highlight: vm.step)
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
                    Text(vm.isPracticing ? "Tap a word to show or hide it" : "Tap to recite · swipe to change passage")
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
        .overlay(alignment: .top) {
            LinearGradient(colors: [Theme.bg, Theme.bg.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 16)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [Theme.bg.opacity(0), Theme.bg], startPoint: .top, endPoint: .bottom)
                .frame(height: 28)
                .allowsHitTesting(false)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func scripture(for card: Reviewable) -> some View {
        FlowLayout(spacing: 7, lineSpacing: 12) {
            ForEach(Array(card.words.enumerated()), id: \.offset) { idx, word in
                WordView(token: String(word), hidden: vm.isHidden(idx))
                    .font(.scripture(24))
                    .contentShape(Rectangle())
                    .allowsHitTesting(vm.isPracticing)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.22)) { vm.toggleWord(idx) }
                    }
            }
        }
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 8) {
            optionsButton
            hideButton
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 8)
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
                Task { await voice.start(reference: card.words.map(String.init)) }
            case .preparingModel:
                break
            }
        } label: {
            switch voice.state {
            case .preparingModel:
                ProgressView()
                    .controlSize(.small)
                    .tint(Theme.muted)
            case .listening:
                Image(systemName: "mic.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ember)
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
        .buttonStyle(.icon)
    }

    private var optionsButton: some View {
        Button {
            showingOptions = true
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.muted)
                .iconButtonChrome()
        }
        .buttonStyle(.plain)
    }

    private var hideButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.28)) { vm.hide() }
        } label: {
            Text("Hide \(vm.hideCount)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.accentPale)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Theme.accent.opacity(0.22), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Theme.accent.opacity(0.42), lineWidth: 1)
                )
                .opacity(vm.canHide ? 1 : 0.32)
        }
        .buttonStyle(.plain)
        .disabled(!vm.canHide)
    }

    private var emptyQueue: some View {
        Text("Nothing to review yet.")
            .font(.body)
            .foregroundStyle(Theme.muted)
            .multilineTextAlignment(.center)
    }
}

private struct WordView: View {
    let token: String
    let hidden: Bool

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
                        if hidden {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Theme.accent.opacity(0.5))
                                .frame(height: 2)
                                .offset(y: 2)
                        }
                    }
            }
            if !p.trail.isEmpty { Text(p.trail).foregroundStyle(Theme.ink) }
        }
    }
}

private extension View {
    func iconButtonChrome() -> some View {
        self
            .frame(width: 48, height: 48)
            .background(Theme.muted.opacity(0.06), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Theme.muted.opacity(0.22), lineWidth: 1)
            )
            .contentShape(Rectangle())
    }
}
