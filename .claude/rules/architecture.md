---
paths:
  - "MemorizationGame/**/*.swift"
---

# Layering

- `Store/AppStore.swift` is the single `@Observable` source of truth (`passages`, `reviewables`), persisted to JSON in the documents directory on every mutation. Views call methods on it; never mutate models directly.
- `Model/` — `Passage` and `Reviewable` (a chunk with `expectedText` + `hiddenWords: Set<Int>`).
- `Logic/` — pure, view-free rules. No SwiftUI imports: `HiddenWordAlignment` (remap hidden indices when a passage is edited), `PracticeLog` (words-per-day + streak), `RecitationMatcher`/`RecitationContext`, `StreakReminder`, `Tunables` (`AppSettings`).
- `Feature/` — one folder per screen: `Library`, `Session`, `Import`, `Settings`, `Achievements`, `Onboarding`, `Contact`, `SpeechHistory`, `ReleaseNotes`, `Splash`.
- `Theme/` — design tokens and shared chrome. `design-theme.html` at the repo root is the canonical visual reference.
- `Support/` — small helpers with no screen of their own.
