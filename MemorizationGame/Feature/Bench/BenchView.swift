#if DEBUG
import SwiftUI

struct BenchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @State private var conformer = BenchConformer()

    var body: some View {
        Screen {
            ScreenHeader(title: "Recitation Bench", onBack: { dismiss() }) { EmptyView() }
        } content: {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    OptionSection(label: "Prayers") {
                        ForEach(Array(BenchPrayer.allCases.enumerated()), id: \.element.id) { index, prayer in
                            if index > 0 { HairlineDivider() }
                            NavigationLink {
                                BenchTakeView(passage: prayer.passage)
                            } label: {
                                DisclosureRow(prayer.title)
                            }
                            .buttonStyle(.haptic)
                        }
                    }
                    OptionSection(label: "Your library", footer: "Free takes only: recite as it went in practice, then mark your slips.") {
                        ForEach(Array(store.passagesSorted.enumerated()), id: \.element.id) { index, passage in
                            if index > 0 { HairlineDivider() }
                            NavigationLink {
                                BenchTakeView(passage: libraryPassage(passage))
                            } label: {
                                DisclosureRow(passage.title)
                            }
                            .buttonStyle(.haptic)
                        }
                    }
                    OptionSection(label: "Conformer", footer: conformer.progress.isEmpty ? nil : conformer.progress) {
                        Button {
                            Task { await conformer.run() }
                        } label: {
                            DisclosureRow(conformer.isRunning ? "Running…" : "Run \(conformer.models.count) models on \(conformer.takes.count) takes")
                        }
                        .buttonStyle(.haptic)
                        .disabled(conformer.isRunning)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.screen)
            }
        }
    }

    private func libraryPassage(_ passage: Passage) -> BenchPassage {
        BenchPassage(
            key: passage.title,
            title: passage.title,
            text: passage.text,
            cards: [.free]
        )
    }
}

struct BenchTakeView: View {
    let passage: BenchPassage

    @Environment(\.dismiss) private var dismiss
    @State private var recorder = BenchRecorder()
    @State private var selected: BenchCard?
    @State private var slips: Set<Int> = []
    @State private var saved: [BenchTake] = []
    @State private var error: String?

    private var words: [String] { Passage.tokens(in: passage.text).map(String.init) }

    private var applicable: [(BenchCard, BenchCard.Resolution)] {
        passage.cards.compactMap { card in card.resolve(in: words).map { (card, $0) } }
    }

    private var resolution: BenchCard.Resolution? {
        selected.flatMap { $0.resolve(in: words) }
    }

    var body: some View {
        Screen {
            ScreenHeader(title: passage.title, onBack: {
                recorder.discard()
                dismiss()
            }) { EmptyView() }
        } content: {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    cardPicker
                    if let selected { instruction(selected) }
                    passageText
                    controls
                    if let error {
                        Text(error)
                            .appFont(Typography.caption)
                            .foregroundStyle(Theme.warn)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.screen)
            }
        }
        .onAppear {
            saved = BenchRecorder.savedTakes()
            selected = selected ?? applicable.first { done(for: $0.0) < $0.0.repeats }?.0
        }
        .onDisappear { recorder.discard() }
    }

    private func done(for card: BenchCard) -> Int {
        saved.filter { $0.card == card.id && $0.prayer == passage.key }.count
    }

    private var cardPicker: some View {
        OptionSection(label: "Cards") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(applicable, id: \.0.id) { card, _ in
                        let count = done(for: card)
                        Button {
                            guard recorder.state == .idle else { return }
                            selected = card
                            slips = []
                        } label: {
                            Text(card.isOpenEnded ? "\(card.id) \(count)" : "\(card.id) \(count)/\(card.repeats)")
                                .appFont(Typography.label)
                                .foregroundStyle(selected == card ? Theme.bg : count >= card.repeats ? Theme.faint : Theme.ink)
                                .padding(.vertical, Spacing.xs)
                                .padding(.horizontal, Spacing.md)
                                .background(
                                    selected == card ? Theme.accent : Theme.bg,
                                    in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                                )
                        }
                        .buttonStyle(.haptic)
                    }
                }
                .padding(Spacing.md)
            }
        }
    }

    private func instruction(_ card: BenchCard) -> some View {
        Text(card.instruction)
            .appFont(Typography.subtitle)
            .foregroundStyle(Theme.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var passageText: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            FlowLayout(spacing: Spacing.xs, lineSpacing: Spacing.sm) {
                ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                    Button {
                        guard recorder.state == .recorded || recorder.state == .playing else { return }
                        if slips.contains(index) { slips.remove(index) } else { slips.insert(index) }
                    } label: {
                        wordLabel(word, at: index)
                    }
                    .buttonStyle(.haptic)
                }
            }
            if recorder.state == .recorded || recorder.state == .playing {
                Text("Listen back and tap every word you got wrong or left out.")
                    .appFont(Typography.caption)
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(Spacing.lg)
        .cardSurface(cornerRadius: Radius.group)
    }

    private func wordLabel(_ word: String, at index: Int) -> some View {
        let unsaid = resolution?.unsaid.contains(index) ?? false
        let anchored = resolution?.anchored.contains(index) ?? false
        let slipped = slips.contains(index)
        return Text(word)
            .appFont(Typography.verse)
            .foregroundStyle(slipped ? Theme.missed : unsaid ? Theme.faint : anchored ? Theme.accent : Theme.ink)
            .strikethrough(unsaid || slipped)
            .underline(resolution?.startIndex == index)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(status)
                .appFont(Typography.label)
                .foregroundStyle(Theme.muted)
            HStack(spacing: Spacing.md) {
                switch recorder.state {
                case .idle, .failed:
                    action("Record", prominent: true) { Task { await recorder.record() } }
                        .disabled(selected == nil)
                case .recording:
                    action("Stop", prominent: true) { recorder.stop() }
                case .recorded:
                    action("Play") { recorder.play() }
                    action("Save", prominent: true) { save() }
                    action("Discard") {
                        recorder.discard()
                        slips = []
                    }
                case .playing:
                    action("Stop") { recorder.stop() }
                    action("Save", prominent: true) { save() }
                }
            }
        }
    }

    private var status: String {
        switch recorder.state {
        case .idle: "Ready"
        case .recording: String(format: "Recording %.0fs", recorder.elapsed)
        case .recorded: String(format: "Recorded %.1fs", recorder.elapsed)
        case .playing: "Playing"
        case .failed(let reason): "Failed: \(reason)"
        }
    }

    private func action(_ title: String, prominent: Bool = false, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Text(title)
                .appFont(Typography.button)
                .foregroundStyle(prominent ? Theme.bg : Theme.ink)
                .padding(.vertical, Spacing.md)
                .frame(maxWidth: .infinity)
                .background(
                    prominent ? Theme.accent : Theme.raised,
                    in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                )
        }
        .buttonStyle(.haptic)
    }

    private func save() {
        guard let selected, let resolution else { return }
        let take = BenchTake(
            card: selected.id,
            prayer: passage.key,
            words: words,
            unsaid: resolution.unsaid,
            startIndex: resolution.startIndex,
            slips: slips.sorted(),
            seconds: recorder.elapsed,
            sampleRate: BenchRecorder.format.sampleRate,
            recordedAt: Date()
        )
        do {
            try recorder.save(take)
            error = nil
            slips = []
            saved = BenchRecorder.savedTakes()
            if done(for: selected) >= selected.repeats {
                self.selected = applicable.first { done(for: $0.0) < $0.0.repeats }?.0 ?? selected
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
#endif
