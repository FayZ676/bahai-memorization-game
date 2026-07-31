import SwiftUI

struct ImportView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.popToLibrary) private var popToLibrary

    @State private var title: String
    @State private var content: String
    private let author: String?
    private let section: String?
    private let editing: Passage?

    init(initialTitle: String = "", initialContent: String = "", author: String? = nil, section: String? = nil) {
        _title = State(initialValue: initialTitle)
        _content = State(initialValue: initialContent)
        self.author = author
        self.section = section
        self.editing = nil
    }

    init(editing passage: Passage, store: AppStore) {
        _title = State(initialValue: passage.title)
        _content = State(initialValue: store.queue(for: passage)
            .map { $0.expectedText.replacingOccurrences(of: "\n", with: " ") }
            .joined(separator: "\n"))
        self.author = passage.author
        self.section = passage.section
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

    var body: some View {
        Screen {
            ScreenHeader(title: editing == nil ? "Import" : "Edit", onBack: { dismiss() }) {
                Button {
                    if let editing {
                        store.updatePassage(editing, title: trimmedTitle, units: units)
                        dismiss()
                    } else {
                        store.createPassage(title: trimmedTitle, units: units, author: author, section: section)
                        popToLibrary()
                    }
                } label: {
                    Text(editing == nil ? "Add" : "Save")
                        .appFont(Typography.body)
                        .foregroundStyle(isValid ? Theme.accent : Theme.disabled)
                }
                .buttonStyle(.haptic)
                .disabled(!isValid)
                .tourAnchor(editing == nil ? .importPrayer : nil)
            }
        } content: {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                        .padding(12)
                        .cardSurface(cornerRadius: Radius.control)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Each line becomes one card.")
                            .appFont(Typography.label)
                            .foregroundStyle(Theme.ink)

                        Text("Paste your text with one verse per line.")
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
