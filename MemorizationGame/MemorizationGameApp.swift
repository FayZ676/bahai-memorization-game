import SwiftUI

@main
struct MemorizationGameApp: App {
    @State private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environment(store)
                .tint(Theme.accent)
                .preferredColorScheme(.dark)
                .task { ReminderScheduler.sync(store.settings) }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.applyDecay() }
                }
        }
    }
}
