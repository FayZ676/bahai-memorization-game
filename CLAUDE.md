# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Verses — an iOS SwiftUI app for memorizing Bahá'í prayers and scripture by hiding words. Hiding is
manual and permanent until you show a word again — tap words to hide/reveal, paint across them to
sweep. No decay, no scoring, no streak-gating; the streak card and achievements are a record, never
a gate. All chunks are freely reachable; a session opens on the furthest chunk that still has hidden
words.

## Build

Xcode project `MemorizationGame.xcodeproj`, scheme `MemorizationGame`. Tested live on a physical
device, not the simulator.

`xcodebuild -project MemorizationGame.xcodeproj -scheme MemorizationGame -configuration Debug build`

## Rules

Conventions live in `.claude/rules/`, most of them scoped by path so they load only when you touch
the code they govern.

| Rule | Loads when |
| --- | --- |
| `git.md` — never commit, never push | always |
| `swift-style.md` — no comments, theme tokens, haptics | any app `.swift` |
| `architecture.md` — store, model, logic, feature layering | any app `.swift` |
| `persistence.md` — hand-written `Codable`, back-compat | `Model/`, `Store/` |
| `recitation.md` — forced alignment, the trouble log, Contact | recitation and its screens |
| `design-assets.md` — the generator is the source | `Design/`, `Assets.xcassets` |
| `releasing.md` — `/release` is the single door | `scripts/`, store listing |
