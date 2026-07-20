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
        let today = Date()
        return HStack(alignment: .bottom, spacing: 8) {
            BurningNumberView(
                value: store.streakCount,
                today: FlameDay(
                    words: store.practiceLog.words(on: today),
                    heat: store.practiceLog.heat(on: today)
                ),
                fontSize: 44
            )
            Text("Day Streak")
                .font(Typography.footnote)
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(Theme.faint)
                .padding(.bottom, 14)
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No passages yet.\nImport one to get started.")
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
        let fading = store.sectionFading(for: passage)
        let fadingCount = fading.count(where: { $0 })
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(passage.title)
                        .font(Typography.title)
                        .foregroundStyle(Theme.ink)

                    Text("Added \(passage.dateAdded.formatted(.dateTime.month(.abbreviated).day().year()))")
                        .font(Typography.footnote)
                        .foregroundStyle(Theme.faint)
                }

                if fadingCount > 0 {
                    Spacer(minLength: 8)
                    Text("\(fadingCount) Section\(fadingCount == 1 ? "" : "s") Fading")
                        .font(Typography.footnote)
                        .foregroundStyle(Color(hex: 0xA05A2C))
                        .fixedSize()
                }
            }

            HeatStrip(heats: store.sectionHeats(for: passage), fading: fading, mergeableGaps: store.mergeableGaps(for: passage))
                .frame(height: 6)
        }
        .padding(.vertical, 6)
    }
}
