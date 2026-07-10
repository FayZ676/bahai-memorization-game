import SwiftUI

struct LibraryView: View {
    @Environment(AppStore.self) private var store
    @State private var pendingDelete: Passage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScreenHeader(title: "Library", leading: {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.icon)
                }, trailing: {
                    NavigationLink {
                        ImportView()
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.icon)
                })

                Group {
                    if store.passages.isEmpty {
                        emptyState
                    } else {
                        list
                    }
                }
            }
            .background(Theme.bg)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Passage.self) { passage in
                SessionView(passage: passage)
            }
        }
        .confirmationDialog(
            "Delete this passage?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { passage in
            Button("Delete", role: .destructive) { store.deletePassage(passage) }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { passage in
            Text("“\(passage.title)” and all its progress will be removed. This can't be undone.")
        }
    }

    private var list: some View {
        List {
            ForEach(store.passagesSorted) { passage in
                PassageRow(passage: passage)
                    .overlay {
                        NavigationLink(value: passage) { EmptyView() }
                            .opacity(0)
                    }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Theme.rowBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Theme.hairline, lineWidth: 1)
                        )
                )
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        pendingDelete = passage
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listRowSpacing(12)
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No passages yet.\nImport one to get started.")
                .font(.body)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PassageRow: View {
    @Environment(AppStore.self) private var store
    let passage: Passage

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(passage.title)
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.ink)

            ChunkHeatStrip(heats: store.chunkHeats(for: passage))
                .frame(height: 3)
        }
        .padding(.vertical, 6)
    }
}
