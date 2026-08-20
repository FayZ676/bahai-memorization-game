import SwiftUI

extension EnvironmentValues {
    @Entry var showReleaseNotes: () -> Void = {}
}

extension View {
    func releaseNotes(_ note: Binding<ReleaseNote?>) -> some View {
        modifier(ReleaseNotesPresenter(note: note))
    }
}

private struct ReleaseNotesPresenter: ViewModifier {
    @Binding var note: ReleaseNote?

    func body(content: Content) -> some View {
        content
            .environment(\.showReleaseNotes) { note = ReleaseNotes.latest }
            .overlay {
                if let note {
                    ReleaseNotesOverlay(note: note) { self.note = nil }
                }
            }
            .animation(Motion.standard, value: note?.version)
    }
}
