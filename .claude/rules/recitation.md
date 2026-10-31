---
paths:
  - "MemorizationGame/Logic/Conformer*.swift"
  - "MemorizationGame/Feature/Session/ConformerRecitation.swift"
  - "MemorizationGame/Feature/Session/VoiceRecitationController.swift"
  - "MemorizationGame/Feature/Bench/**/*.swift"
  - "MemorizationGame/Logic/BenchCard.swift"
  - "MemorizationGame/Resources/Conformer.mlpackage/**"
  - "Tools/RecitationBench/**"
---

# Recitation

Recitation is forced alignment against the known text. `Resources/Conformer.mlpackage` (NVIDIA
Conformer-CTC medium, 16-bit) turns each 6 s window of 16 kHz audio into word-piece
probabilities; `ConformerAligner` aligns the passage to them; `ConformerTracker` credits a word
only when its every piece fits, removing it clearly worsens the alignment, and a frame within
80 ms of it is speech (a word piece, not blank, is most likely) — without that speech gate the
first owed word gets credited from room noise when recitation starts. `ConformerSession`
keeps the work bounded: it starts at the chosen paragraph's first word, aligns a 64-word span, and
re-anchors just behind the last credit (keeping 8 words of overlap) so a long prayer recited for
minutes costs the same per second as a short one. Audio stays on the device. Matching must not
forgive meaning: *my/Thy*, *me/Thee*, *myself/Thyself* must fail. The tokenizer folds accents
(*Aḥmad* → *ahmad*, *‘Alí* → *ali*): the model's vocabulary is plain English letters, so an
accented letter would become an unknown piece no recitation can ever match. Folding is spelling,
not forgiveness — it changes only words that carry accents, and no library word may tokenize to
an unknown piece.

`Tools/RecitationBench/SPEC.md` is the contract. Truth comes from the script card or from the
reciter marking slips by ear — never from a recognizer's transcript. A change to the model, the
aligner or the commit rule is judged by replaying every take in `Tools/RecitationBench/takes`
(the Swift harness in `Tools/RecitationBench/conformer/` runs the app's own logic on the Mac),
and it ships only if no wrong word gets credited.

The model is generated, not edited: `candidates/coreml_convert.py` builds it from NeMo, and
`candidates/export_vocabulary.py` writes `conformer-vocabulary.json` beside it.

New test cases come from the phone. In a debug build, Settings → Debug → Recitation Bench → a
passage → the Free card: recite the way it went wrong, listen back, tap every word that was wrong
or left out, save. `Tools/RecitationBench/pull-takes.sh` copies every new take off the phone.

Misses show as a flash and shake on the owed word: something was said after the reciter reached
it, then 2 s of quiet passed without it being credited. Silence alone never flashes. The second miss
on the same word un-hides it for good, like a manual reveal (`VoiceRecitationController.missesBeforeShowing`) — there is no
tap-to-reveal while reciting; a tap anywhere stops.
