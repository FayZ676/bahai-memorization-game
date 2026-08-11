# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

iOS SwiftUI app for memorizing Bahá'í prayers/scripture by hiding words. Hiding is manual and permanent until you show a word again — tap words to hide/reveal, paint across them to sweep. No decay, no scoring, no streak-gating; the streak card and achievements are a record, never a gate.

## Build

Xcode project `MemorizationGame.xcodeproj`, scheme `MemorizationGame`. Tested live on a physical device, not the simulator.
`xcodebuild -project MemorizationGame.xcodeproj -scheme MemorizationGame -configuration Debug build`

## Architecture

- `Store/AppStore.swift` — single `@Observable` source of truth (`passages`, `reviewables`), persisted to JSON in documents dir on every mutation. Views call methods on it; never mutate models directly.
- `Model/Models.swift` — `Passage` and `Reviewable` (a chunk with `expectedText` + `hiddenWords: Set<Int>`). Hand-written `Codable` for backward compat with old snapshots — use `decodeIfPresent` + fallback when adding fields.
- `Logic/` — pure, view-free rules: `HiddenWordAlignment` (remap hidden indices when a passage is edited), `PracticeLog` (words-per-day + streak), `RecitationMatcher`/`RecitationContext` (speech matching), `StreakReminder`, `Tunables` (`AppSettings`).
- `Feature/` — one folder per screen (`Library`, `Session`, `Import`, `Settings`, `Achievements`, `Onboarding`, `SpeechLogs`).
- Speech Logs — `RecitationMatcher` records every burnt word (expected word, what was heard in
  its place, both phonetic keys); `Store/RecitationLog.swift` persists the last few attempts per
  chunk to `recitation-log.json`, the screen reads it, and problem feedback ships it.
- `Theme/` — all colors/type/spacing as design tokens (`Theme.swift`, `Typography.swift`, etc.); never hardcode values in views. `design-theme.html` at repo root is the canonical visual reference.
- `Design/` — generators for art that ships as an asset, one folder per thing, each with a README that is the source of truth for it: `AppIcon/` (the nine-pointed star, rasterised into `Assets.xcassets`) and `StoreFrames/` (App Store screenshots). The asset is the artefact — edit the generator, never the output. Read the folder's README before changing anything there.

## Releasing

`/release` is the single door for shipping — it drives the helpers in `scripts/`
(`release-diff.sh`, `check-listing.py`, `project_version.py`, `push-build.sh`).
See `scripts/README.md` for the one-time App Store Connect API key setup.

## Conventions

- No code comments. Naming and structure carry the explanation.
- Every button press fires haptic feedback via centralized button styles/`Support/Feedback.swift`.
