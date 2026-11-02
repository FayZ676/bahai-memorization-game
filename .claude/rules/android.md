---
paths:
  - "android/**"
---

# Android

- `android/logic` is a line-for-line port of `MemorizationGame/Logic` (and the pure parts of `Model/`
  and `Support/`). A change to one is a change to both; keep names and structure parallel so a diff
  reads across.
- Recitation parity is measured, not argued: `android/scripts/bench.sh` must credit exactly what the
  Swift harness credits (`Tools/RecitationBench/conformer`, `live` mode) — same words, same flashes,
  no wrong word. Diff the two JSONs per take, not just the totals.
- Same conventions as the Swift app: no comments, every value from `theme/`, every press fires
  haptics through `Modifier.haptic` / `IconButton` and `support/Feedback.kt`, never at the call site.
- Compose modifier order matters: `background` before `alpha` is not faded, `onSizeChanged` after
  `statusBarsPadding` misses the inset.
- Debug-only test hooks live in `app/src/debug` (`BenchActivity`) and behind `BuildConfig.DEBUG`
  (`files/replay.raw` stands in for the microphone). Release builds never contain them.
- Never commit `release.keystore` or `keystore.properties`.
