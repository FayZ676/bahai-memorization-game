# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Verses — an iOS SwiftUI app for memorizing Bahá'í prayers and scripture by hiding words. Hiding is
manual and permanent until you show a word again — tap words to hide/reveal, paint across them to
sweep. No decay, no scoring, no streaks; achievements are a record, never a gate. Reciting aloud
reveals hidden words as they are said, recognized on the device by a bundled Conformer model. A
prayer is one scrollable page that opens at the top; practice starts at the paragraph at the top of
the screen, or the one whose ¶ was tapped, and runs as far as you recite.

## Android

`android/` is a native Kotlin + Jetpack Compose port with the same recitation engine (the
Conformer exported to ONNX). `android/README.md` covers the emulator, the bench and Play release.

## Build

Xcode project `MemorizationGame.xcodeproj`, scheme `MemorizationGame`. Tested live on a physical
device, not the simulator.

`xcodebuild -project MemorizationGame.xcodeproj -scheme MemorizationGame -configuration Debug build`

The recitation model (`MemorizationGame/Resources/Conformer.mlpackage`) and the bench recordings
(`Tools/RecitationBench/takes/*.wav`) live in Git LFS. A fresh clone needs `git lfs install` and
`git lfs pull` before it builds.

## Rules

Conventions live in `.claude/rules/`, most of them scoped by path so they load only when you touch
the code they govern.

| Rule | Loads when |
| --- | --- |
| `git.md` — never commit, never push | always |
| `swift-style.md` — no comments, theme tokens, haptics | any app `.swift` |
| `architecture.md` — store, model, logic, feature layering | any app `.swift` |
| `persistence.md` — hand-written `Codable`, back-compat | `Model/`, `Store/` |
| `recitation.md` — the Conformer, the bench, adding test cases | recitation, the bench, its tools |
| `design-assets.md` — the generator is the source | `Design/`, `Assets.xcassets` |
| `releasing.md` — `/release` is the single door | `scripts/`, store listing |
| `android.md` — logic stays in step with iOS, the bench is the contract | `android/**` |
