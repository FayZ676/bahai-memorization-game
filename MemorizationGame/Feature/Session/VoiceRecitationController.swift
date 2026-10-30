import AVFoundation
import Observation

@MainActor
@Observable
final class VoiceRecitationController {
    enum State: Equatable {
        case idle
        case preparingModel
        case listening
        case micDenied
        case failed
    }

    private(set) var state: State = .idle {
        didSet { RecitationTrace.emit("state", "\(oldValue) -> \(state)") }
    }
    private(set) var cursorIndex: Int?
    var onWordsMatched: (([Int]) -> Void)?
    var onMiss: ((Int) -> Void)?
    var onWordShown: ((Int) -> Void)?
    var onCompleted: (() -> Void)?

    private let capture = AudioCapture()
    private var listener: ConformerRecitation?
    private var owed: Set<Int> = []
    private var misses: [Int: Int] = [:]

    private static let missesBeforeShowing = 2

    var isListening: Bool { state == .listening }

    #if DEBUG
    func stageListeningForCapture(cursor: Int?) {
        state = .listening
        cursorIndex = cursor
    }
    #endif

    func prepare() {
        ConformerRecitation.preload()
    }

    func start(words: [String], hiddenIndices: [Int], from startWord: Int) async {
        RecitationTrace.begin()
        RecitationTrace.emit("start", "words=\(words.count) from=\(startWord) hidden=\(hiddenIndices)")
        guard !hiddenIndices.isEmpty else { return }
        guard state == .idle || state == .failed || state == .micDenied else { return }
        guard await Self.micPermissionGranted() else {
            state = .micDenied
            return
        }
        state = .preparingModel
        do {
            let listener = try await ConformerRecitation.make(
                words: words,
                hidden: hiddenIndices,
                start: startWord,
                onCredits: { [weak self] in self?.credit($0) },
                onFlash: { [weak self] in self?.flash($0) }
            )
            guard state == .preparingModel else { return }
            self.listener = listener
            owed = Set(hiddenIndices)
            misses = [:]
            cursorIndex = hiddenIndices.min()
            try await capture.start(feeding: listener)
            guard state == .preparingModel else { return }
            state = .listening
        } catch {
            RecitationTrace.emit("start", "FAILED \(error)")
            state = .failed
            teardown()
        }
    }

    func updateHiddenIndices(_ hiddenIndices: [Int]) {
        guard state == .listening, let listener else { return }
        listener.updateHidden(hiddenIndices)
        owed = Set(hiddenIndices)
        cursorIndex = hiddenIndices.min()
        if owed.isEmpty { stop() }
    }

    func stop() {
        guard state != .idle else { return }
        if state != .micDenied { state = .idle }
        teardown()
    }

    private func credit(_ indices: [Int]) {
        let fresh = indices.filter { owed.contains($0) }
        guard !fresh.isEmpty else { return }
        owed.subtract(fresh)
        onWordsMatched?(fresh)
        advance()
    }

    private func advance() {
        guard state == .listening else { return }
        cursorIndex = owed.min()
        if owed.isEmpty {
            stop()
            onCompleted?()
        }
    }

    private func flash(_ index: Int) {
        guard state == .listening, owed.contains(index) else { return }
        onMiss?(index)
        misses[index, default: 0] += 1
        guard misses[index, default: 0] >= Self.missesBeforeShowing else { return }
        owed.remove(index)
        listener?.updateHidden(Array(owed))
        onWordShown?(index)
        advance()
    }

    private func teardown() {
        listener?.finish()
        listener = nil
        capture.stop()
        cursorIndex = nil
    }

    private static func micPermissionGranted() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return true
        case .denied: return false
        default: return await AVAudioApplication.requestRecordPermission()
        }
    }
}
