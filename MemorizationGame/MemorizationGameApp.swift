import SwiftUI

@main
struct MemorizationGameApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environment(store)
                .tint(Theme.accent)
                .preferredColorScheme(.dark)
                .task { ReminderScheduler.sync(store.settings) }
        }
    }
}
