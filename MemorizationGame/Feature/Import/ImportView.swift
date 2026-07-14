import SwiftUI

struct ImportView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var content = ""

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var units: [String] {
        content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var isValid: Bool { !trimmedTitle.isEmpty && !units.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Import", onBack: { dismiss() }) {
                Button {
                    store.createPassage(title: trimmedTitle, units: units)
                    dismiss()
                } label: {
                    Text("Add")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isValid ? Theme.accent : Theme.disabled)
                }
                .buttonStyle(.haptic)
                .disabled(!isValid)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                        .padding(12)
                        .background(Theme.rowBg, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline))

                    Text("One verse per line. Remove line breaks that aren't real boundaries — like word-wrap from a pasted PDF — before pasting.")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)

                    ZStack(alignment: .topLeading) {
                        if content.isEmpty {
                            Text(Self.placeholder)
                                .font(.scripture(19))
                                .foregroundStyle(Theme.muted.opacity(0.6))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $content)
                            .font(.scripture(19))
                            .foregroundStyle(Theme.ink)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 320)
                    }
                    .padding(4)
                    .background(Theme.rowBg, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline))
                    .scriptureFadeEdge(color: Theme.rowBg)
                }
                .padding(16)
            }
        }
        .background(Theme.bg)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    private static let placeholder =
        "In the name of God, the Most Glorious.\nGlory be to Thee, O Lord my God.\nI bear witness to Thy unity and Thy oneness."
}
