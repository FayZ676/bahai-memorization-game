# RecitationHarness

Scenario checks for the two pure-logic files behind voice recitation: `PhoneticKey` and
`RecitationMatcher`. Neither touches SwiftUI, AVFoundation, or Speech, so both compile and
run on the Mac — which means the matching rules can be exercised without a device.

This exists because the project has no Xcode test target. It is not part of the app
target and cannot affect the build.

## Run

```sh
swiftc -O \
  MemorizationGame/Logic/PhoneticKey.swift \
  MemorizationGame/Logic/RecitationMatcher.swift \
  MemorizationGame/Logic/RecitationTrace.swift \
  MemorizationGame/Logic/RecitationRecord.swift \
  Tools/RecitationHarness/main.swift \
  -o /tmp/recitation-harness && /tmp/recitation-harness
```

Exits non-zero on any failure. Run it from the repo root after touching either logic file.

## What it covers

- **Phonetic equivalences** — the ASR confusions that made prayer text unusable:
  Thy/the, Thee/the, Thou/though, hath/has, art/are, unto/into.
- **Phonetic separations** — words that must stay distinct: God/Lord, Son/Spirit,
  mercy/bounty, light/night. The last pair is the reason `sharesOnset` exists; without
  it `lt` and `nt` are one edit apart and collide, as do `bn` and `sn`.
- **Clean recitation at speed** — a full line delivered as one settled utterance matches
  every hidden word.
- **Moved-on detection** — fumbling a hidden word and continuing marks that word missed
  and keeps matching the rest, instead of cascading failures down the line.
- **Stall and retry** — three settled wrong utterances produce two soft misses and then a
  moved-on miss, and the cursor advances past the burnt word.
- **Volatile safety** — nothing unsettled can commit a miss.
- **Idempotence** — repeated volatile deliveries of a growing transcript match each word
  exactly once.
- **Miss records** — every burnt word records the expected word verbatim, the tokens heard
  in its place (empty when the word was skipped in silence), both phonetic keys, and how the
  word ended: `skipped`, `exhausted`, `revealed`, or `abandoned`.
- **Try records** — every settled utterance spoken while a hidden word was owed, carrying the
  word that was owed, the tokens settled since the previous try, and whether that utterance
  was accepted. Tries are what make a word you said repeatedly — and that never registered —
  visible; without them the log only ever showed words the matcher was confident enough to
  burn, which is the minority of real failures.
- **Silent exits** — a word revealed by hand mid-recitation, or still owed when listening
  stops, is recorded rather than dropped. Both used to leave no trace at all, and an attempt
  with no matches and no burns used to be discarded wholesale as "empty".

## Known failures

Seven checks fail on `main` and this change neither introduced nor fixed them: the moved-on
burn path withholds a miss whenever anything was heard in the gap (`displaced.isEmpty` in
`RecitationMatcher.ingest`), so "fumble then speak straight past it" and "a word skipped in
silence" record nothing. Whether the withhold or the expectation is wrong is a tuning
question — settle it against a device trace, not by reasoning.

## Note on timings

`tokens(_:from:gap:)` synthesises `HeardToken` audio times. The default 0.1 s gap keeps a
phrase inside one utterance; the retry scenario steps the clock by 5 s to force separate
utterances, since attempts are counted per utterance and `RecitationMatcher.utteranceGap`
is 0.6 s.
