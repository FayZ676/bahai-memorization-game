import SwiftUI

@main
struct MemorizationGameApp: App {
    @State private var store = AppStore()
    @State private var splashFinished = false
    @State private var splashCleared = false

    init() {
        AppFont.register()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                LibraryView()
                    .environment(store)
                    .environment(\.fontScale, store.settings.fontSize.scale)
                    .opacity(splashFinished ? 1 : 0)
                    .task { ReminderScheduler.sync(store.settings) }

                if !splashCleared {
                    SplashView { splashFinished = true }
                        .opacity(splashFinished ? 0 : 1)
                        .allowsHitTesting(!splashFinished)
                        .zIndex(1)
                }
            }
            .dynamicTypeSize(...DynamicTypeScaling.contentLimit)
            .animation(Motion.handoff, value: splashFinished)
            .task(id: splashFinished) {
                guard splashFinished else { return }
                try? await Task.sleep(for: .seconds(Motion.handoffDuration))
                splashCleared = true
            }
            #if DEBUG
            .task {
                guard ProcessInfo.processInfo.environment["BENCH_CONFORMER"] == "1" else { return }
                let conformer = BenchConformer()
                print("bench-conformer start models=\(conformer.models.count) takes=\(conformer.takes.count)")
                await conformer.run()
                print("bench-conformer finished: \(conformer.progress)")
            }
            .task {
                guard ProcessInfo.processInfo.environment["BENCH_LIVE"] == "1" else { return }
                await BenchLive.run()
            }
            .task {
                guard ProcessInfo.processInfo.environment["LAYOUT_CHECK"] == "1" else { return }
                BenchLayoutCheck.run()
            }
            #endif
            .tint(Theme.accent)
            .preferredColorScheme(store.settings.appTheme.colorScheme)
        }
    }
}
