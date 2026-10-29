---
paths:
  - "MemorizationGame/**/*.swift"
---

# Layering

- `Store/AppStore.swift` is the single `@Observable` source of truth (`passages`), persisted to JSON in the documents directory on every mutation. Views call methods on it; never mutate models directly.
- `Model/` — `Passage`: a prayer's `text` (one line per paragraph) and `hiddenWords: Set<Int>` over its words. There are no chunks.
- `Logic/` — pure, view-free rules. No SwiftUI imports: `HiddenWordAlignment` (remap hidden indices when a passage is edited), `ConformerTokenizer`/`ConformerAligner`/`ConformerTracker`/`ConformerSession` (recitation), `Tunables` (`AppSettings`).
- `Feature/` — one folder per screen: `Library`, `Session`, `Import`, `Settings`, `Achievements`, `Onboarding`, `Contact`, `ReleaseNotes`, `Splash`, and `Bench` (debug builds only).
- `Theme/` — design tokens and shared chrome. `design-theme.html` at the repo root is the canonical visual reference.
- `Support/` — small helpers with no screen of their own.
- The session page is laid out by `Feature/Session/PageLayout.swift`, not by SwiftUI flow: it measures every word with the exact `UIFont` the page draws with (Dynamic Type included), so word, line and paragraph positions are known before drawing. That is what lets the page draw only paragraphs near the screen, snap to paragraph tops, and hit-test touches without per-word geometry. Draw words with `layout.font`, never a separately resolved font, or positions drift.
