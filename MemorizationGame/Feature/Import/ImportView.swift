import SwiftUI

struct ImportView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.popToLibrary) private var popToLibrary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var title: String
    @State private var content: String
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
        _content = State(initialValue: store.passage(withID: passage.id)?.text ?? passage.text)
        self.author = passage.author
        self.section = passage.section
        self.sourceID = passage.sourceID
        self.editing = passage
    }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var paragraphs: [String] {
        Passage.paragraphs(in: content)
    }

    private var isValid: Bool { !trimmedTitle.isEmpty && !paragraphs.isEmpty }

    var body: some View {
        Screen {
            ScreenHeader(
                title: editing == nil ? "Import" : "Edit",
                onBack: { dismiss() },
                slotWidth: 38
            ) {
                Button {
                    if let editing {
                        store.updatePassage(editing, title: trimmedTitle, text: paragraphs.joined(separator: "\n"))
                        dismiss()
                    } else {
                        store.createPassage(
                            title: trimmedTitle,
                            text: paragraphs.joined(separator: "\n"),
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
                .accessibilityLabel(editing == nil ? "Add to Library" : "Save")
                .disabled(!isValid)
            }
        } content: {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Title")
                            .appFont(Typography.label)
                            .foregroundStyle(Theme.muted)

                        TextField("Title", text: $title)
                            .appFont(Typography.body)
                            .id(dynamicTypeSize)
                            .textInputAutocapitalization(.words)
                            .padding(12)
                            .cardSurface(cornerRadius: Radius.control)
                    }

                    InfoNote(Typography.caption) {
                        Text("Every line of text becomes its own paragraph.")
                            .appFont(Typography.caption)
                            .foregroundStyle(Theme.muted)
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
    }

    private static let placeholder =
        "In the name of God, the Most Glorious.\nGlory be to Thee, O Lord my God.\nI bear witness to Thy unity and Thy oneness."
}
