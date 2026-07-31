# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

iOS SwiftUI app for memorizing Bahá'í prayers/scripture by hiding words. Hidden words silently decay (re-reveal) over time if not practiced; no scoring/streak-gating beyond that.

## Build

Xcode project `MemorizationGame.xcodeproj`, scheme `MemorizationGame`. Tested live on a physical device, not the simulator.
`xcodebuild -project MemorizationGame.xcodeproj -scheme MemorizationGame -configuration Debug build`

## Architecture

- `Store/AppStore.swift` — single `@Observable` source of truth (`passages`, `reviewables`), persisted to JSON in documents dir on every mutation. Views call methods on it; never mutate models directly.
- `Model/Models.swift` — `Passage` and `Reviewable` (a chunk with `expectedText` + `hiddenWords: Set<Int>`). Hand-written `Codable` for backward compat with old snapshots — use `decodeIfPresent` + fallback when adding fields.
- `Logic/DecayModel.swift` — pure calculation of how many hidden words should still be hidden given elapsed time; applied on app foreground.
- `Feature/` — one folder per screen (`Library`, `Session`, `Import`, `Settings`).
- `Theme/` — all colors/type/spacing as design tokens (`Theme.swift`, `Typography.swift`, etc.); never hardcode values in views. `design-theme.html` at repo root is the canonical visual reference.
- `Design/` — generators for art that ships as an asset, one folder per thing, each with a README that is the source of truth for it: `AppIcon/` (the nine-pointed star, rasterised into `Assets.xcassets`) and `Badges/` (achievement badge image prompts). The asset is the artefact — edit the generator, never the output. Read the folder's README before changing anything there.

## Conventions

- No code comments unless documenting a genuinely non-obvious invariant.
- Every button press fires haptic feedback via centralized button styles/`Support/Feedback.swift`.
