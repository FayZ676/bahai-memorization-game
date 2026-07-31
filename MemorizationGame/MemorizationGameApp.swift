import SwiftUI

@main
struct MemorizationGameApp: App {
    @State private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AppFont.register()
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environment(store)
                .environment(\.fontScale, store.settings.fontSize.scale)
                .tint(Theme.accent)
                .preferredColorScheme(store.settings.appTheme.colorScheme)
                .task { ReminderScheduler.sync(store.settings) }
                .onChange(of: scenePhase, initial: true) { _, phase in
                    guard phase == .active else { return }
                    store.syncStreakReminder()
                }
        }
    }
}
