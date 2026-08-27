---
paths:
  - "MemorizationGame/Logic/Recitation*.swift"
  - "MemorizationGame/Logic/PhoneticKey.swift"
  - "MemorizationGame/Store/RecitationLog.swift"
  - "MemorizationGame/Feature/SpeechHistory/**/*.swift"
  - "MemorizationGame/Feature/Contact/**/*.swift"
---

# Recitation and the trouble log

Recitation is forced alignment: phonetic keys, whole-transcript alignment, a per-passage custom
language model. Matching must not forgive meaning — near-homophones with different senses
(myself/thyself) must fail. Fix misses at recognition, never by hardcoding equivalences.

Speech is unavailable on the simulator (`SpeechTranscriber.isAvailable` is false on the iOS 26 sim),
so recitation behavior is measured from a device trace, not reasoned about. See `Logic/RECITATION-AUDIT.md`.

`RecitationMatcher` records every burnt word (expected word, what was heard in its place, both
phonetic keys, and how it ended) *and* every failed try — an utterance spoken while a word was owed
that did not credit it — so a word said repeatedly but never registered still shows up. The log
keeps trouble only: a word matched first time is never written down, and the try that finally lands
is kept only for a word that had already failed.

The history filters on misses, skipped, and retries — a miss was voiced and refused, a skip was
never voiced at all, so those two are disjoint. It lives on its own screen,
`Feature/SpeechHistory/SpeechHistoryView.swift`, reachable from Settings and the session options menu.

`Feature/Contact/ContactView.swift` is the one screen behind both "Report Issue" and "Send Feedback";
`ContactPurpose` supplies the title, copy, form kind, and whether the recitation record shows.
Both are reachable from Settings and from the session options menu, and the report purpose offers
a toggle for sending the record along with the note.
