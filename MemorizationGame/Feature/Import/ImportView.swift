import SwiftUI

struct ImportView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.popToLibrary) private var popToLibrary

    @State private var title: String
    @State private var content: String
    @State private var savedWritingID: UUID?
    private let author: String?
    private let section: String?
    private let sourceID: Int?
    private let editing: Passage?

    init(
        initialTitle: String = "",
        initialContent: String = "",
        author: String? = nil,
        section: String? = nil,
        sourceID: Int? = nil
    ) {
        _title = State(initialValue: initialTitle)
        _content = State(initialValue: initialContent)
        self.author = author
        self.section = section
        self.sourceID = sourceID
        self.editing = nil
    }

    init(editing passage: Passage, store: AppStore) {
        _title = State(initialValue: passage.title)
        _content = State(initialValue: store.queue(for: passage)
            .map { $0.expectedText.replacingOccurrences(of: "\n", with: " ") }
            .joined(separator: "\n"))
        self.author = passage.author
        self.section = passage.section
        self.sourceID = passage.sourceID
        self.editing = passage
    }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var units: [String] {
        content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var isValid: Bool { !trimmedTitle.isEmpty && !units.isEmpty }

    private var canSaveToWritings: Bool { editing == nil && sourceID == nil }

    private var canSaveNow: Bool { !units.isEmpty }

    private var savedTitle: String {
        trimmedTitle.isEmpty ? (units.first ?? "") : trimmedTitle
    }

    private func toggleSavedToWritings() {
        if let savedWritingID {
            store.removeSavedWriting(id: savedWritingID)
            self.savedWritingID = nil
        } else {
            savedWritingID = store.saveWriting(title: savedTitle, text: content).id
        }
    }

    private func syncSavedWriting() {
        guard let savedWritingID else { return }
        store.updateSavedWriting(id: savedWritingID, title: savedTitle, text: content)
    }

    var body: some View {
        Screen {
            ScreenHeader(
                title: editing == nil ? "Import" : "Edit",
                onBack: { dismiss() },
                slotWidth: canSaveToWritings ? 84 : 38
            ) {
                HStack(spacing: Spacing.sm) {
                    if canSaveToWritings {
                        Button {
                            Feedback.tap()
                            toggleSavedToWritings()
                        } label: {
                            Image(systemName: savedWritingID == nil ? "bookmark" : "bookmark.fill")
                                .foregroundStyle(canSaveNow ? Theme.accent : Theme.disabled)
                        }
                        .buttonStyle(.icon)
                        .disabled(!canSaveNow)
                    }

                    Button {
                        if let editing {
                            store.updatePassage(editing, title: trimmedTitle, units: units)
                            dismiss()
                        } else {
                            store.createPassage(
                                title: trimmedTitle,
                                units: units,
                                author: author,
                                section: section,
                                sourceID: sourceID
                            )
                            popToLibrary()
                        }
                    } label: {
                        Image(systemName: editing == nil ? "plus" : "checkmark")
                            .foregroundStyle(isValid ? Theme.accent : Theme.disabled)
                    }
                    .buttonStyle(.icon)
                    .disabled(!isValid)
                }
            }
        } content: {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                        .padding(12)
                        .cardSurface(cornerRadius: Radius.control)

                    InfoNote(Typography.label) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Each line becomes one card.")
                                .appFont(Typography.label)
                                .foregroundStyle(Theme.ink)

                            Text("Paste your text with one verse per line.")
                                .appFont(Typography.caption)
                                .foregroundStyle(Theme.muted)
                        }
                    }

                    ZStack(alignment: .topLeading) {
                        if content.isEmpty {
                            Text(Self.placeholder)
                                .appFont(Typography.verse)
                                .foregroundStyle(Theme.muted.opacity(0.6))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $content)
                            .appFont(Typography.verse)
                            .foregroundStyle(Theme.ink)
                            .scrollContentBackground(.hidden)
                            .scrollDisabled(true)
                            .frame(minHeight: 320)
                    }
                    .padding(4)
                    .cardSurface(cornerRadius: Radius.control)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .onChange(of: title) { _, _ in syncSavedWriting() }
        .onChange(of: content) { _, _ in syncSavedWriting() }
        .completesTourStep(.addPrayer)
    }

    private static let placeholder =
        "In the name of God, the Most Glorious.\nGlory be to Thee, O Lord my God.\nI bear witness to Thy unity and Thy oneness."
}
