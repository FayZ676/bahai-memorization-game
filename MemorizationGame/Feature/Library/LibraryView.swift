import SwiftUI

struct LibraryView: View {
    @Environment(AppStore.self) private var store
    @State private var pendingDelete: Passage?
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
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
                        PrayerBrowseView()
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
                SessionView(passage: passage, store: store)
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
            Section {
                streakHeader
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                ForEach(store.passagesSorted) { passage in
                    Button {
                        Feedback.tap()
                        path.append(passage)
                    } label: {
                        PassageRow(passage: passage)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear.cardSurface())
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
        }
        .listRowSpacing(12)
        .contentMargins(.top, 4, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
    }

    private var streakHeader: some View {
        StreakView(count: store.streakCount)
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.sm)
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No passages yet.\nBrowse prayers to get started.")
                .font(Typography.subtitle)
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
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(passage.title)
                        .font(Typography.passageTitle)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 8)

                    Text(passage.dateAdded.elapsedDuration)
                        .font(Typography.footnote)
                        .foregroundStyle(Theme.faint)
                        .fixedSize()
                }
            }

            HeatStrip(heats: store.sectionHeats(for: passage))
                .frame(height: 6)
        }
        .padding(.vertical, 6)
    }
}

private extension Date {
    var elapsedDuration: String {
        let now = Date()
        let units: [(Calendar.Component, String)] = [
            (.year, "y"), (.month, "mo"), (.weekOfYear, "w"), (.day, "d"), (.hour, "h"), (.minute, "m")
        ]
        let parts = Calendar.current.dateComponents(
            [.year, .month, .weekOfYear, .day, .hour, .minute],
            from: self, to: now
        )
        for (component, suffix) in units {
            if let value = parts.value(for: component), value > 0 {
                return "\(value)\(suffix)"
            }
        }
        return "now"
    }
}
