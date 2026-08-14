import SwiftUI

@main
struct MemorizationGameApp: App {
    @State private var store = AppStore()
    @State private var splashFinished = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AppFont.register()
        #if DEBUG
        let problems = AchievementCatalog.problems
        assert(problems.isEmpty, "Broken achievements:\n" + problems.joined(separator: "\n"))
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                LibraryView()
                    .environment(store)
                    .environment(\.fontScale, store.settings.fontSize.scale)
                    .opacity(splashFinished ? 1 : 0)
                    .task { ReminderScheduler.sync(store.settings) }
                    .onChange(of: scenePhase, initial: true) { _, phase in
                        guard phase == .active else { return }
                        store.syncStreakReminder()
                    }

                if !splashFinished {
                    SplashView {
                        withAnimation(Motion.handoff) { splashFinished = true }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .tint(Theme.accent)
            .preferredColorScheme(store.settings.appTheme.colorScheme)
        }
    }
}
