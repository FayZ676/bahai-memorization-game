# Recitation audit — open items

Findings from an audit on 2026-08-12, after a day of device tracing on the
Family Prayer and a purpose-built dummy passage. Two findings were fixed the
same day and are recorded at the bottom for context. Everything below the line
is still open.

Traces are captured by launching the debug build with a console attached:

```
xcrun devicectl device process launch --device <id> --console \
    --terminate-existing com.faizififita.MemorizationGame > trace.log
```

`RecitationTrace` prints `align`, `verdict`, `matcher`, `withhold` and `skipped`
lines that carry everything needed to replay a session offline.

---

## 1. The audio-timing guard switches off at passage boundaries

`RecitationMatcher.unheardSpan` returns `nil` unless an aligned reference word
exists on *both* sides of the candidate. The call site treats `nil` as zero —
"no gap, so the reciter passed it over" — which means the protection added for
transcriber word-merging does not cover any word before the first match or
after the last. Those are the positions where recognition is weakest.

**Fix direction:** fall back to the recitation's own clock at the boundaries —
the start of the first token or the end of the last — instead of giving up and
defaulting to an accusation.

## 2. The attempt-budget escape hatch accuses without the withhold check

The moved-on sweep withholds a miss when unaligned transcriber output sits in
the word's slot. The attempt-budget path that runs after three unproductive
final results inserts into `missed` with no such test, so it can accuse the
reciter in exactly the circumstances the sweep was taught to stay silent about.

This path was dormant for months (see the `judged` fix below) and only became
reachable on 2026-08-12, so it has had almost no real-world exposure.

**Fix direction:** either apply the same displaced/unheard test before the hard
miss, or introduce a third outcome — deferred — that advances the cursor
without ever claiming the word was wrong. `nextExpectedIndex` derives from the
matched/missed sets, so deferral needs to exist as its own concept.

## 3. Contextual strings never reach individual words or ASCII twins

`VoiceRecitationController` passes `hidden: Set(Reviewable.tokens(in: text).indices)`
— every index — so `RecitationContext.contextualStrings` treats the whole
passage as hidden and its first loop emits one four-word window per word. That
saturates `entryLimit` (100) before the ASCII-twin pass and the individual
hidden-word pass ever run. Device traces show `contextualStrings=100` on every
prepare.

Consequences: `Bahá'u'lláh` and friends never get their accent-free twin
submitted, and the archaic function words that actually fail recognition —
`Thee`, `Thy`, `Thyself`, `didst`, `unto` — are never offered as standalone
hints on any passage longer than about a hundred words.

This is the highest-value open item for recognition quality. A stock-dictation
comparison in Notes showed the custom language model already beats Apple's
default decisively on rare vocabulary (`befitteth`, `beseemeth`, `abode`,
`hast`, `inasmuch`) while both fail on the archaic function words — which is
precisely the class this budget is starving.

**Fix direction:** submit individual hidden words before the windows, and pass
the real hidden set rather than every index.

## 4. Differential language-model weighting

`RecitationLanguageModel` gives every phrase the same `count: 20` — the whole
text and every three- and five-word window alike. `PhraseCount(phrase:count:)`
supports per-phrase weighting, so the budget could favour the words that
actually fail.

A device test on 2026-08-12 confirmed the model does **not** fabricate at the
current weight of 0.9: the reciter said "myself" three times and "thyself" five
times against a text reading `thyself`, and the transcriber reported each
faithfully. So boosting has headroom.

**Constraint that must survive any change:** do not boost `Thyself` or `Thine`.
Their competitors are `myself` and `mine`, which invert the meaning of the
prayer and are the exact confusion the app exists to catch. Boosting them would
reintroduce a false pass upstream of the matcher, where no trace can see it.
`Thee`, `Thy`, `Thou`, `didst`, `hast` and `unto` are safe — their competitors
are meaning-preserving.

## 5. One word heard as two

The aligner pairs one spoken token with one reference word. When the
transcriber splits a word — `Thyself unto` arriving as `"self", "on"`, or
`befitteth` as `"we fitted"` — no pairing can succeed, and the words stay
unresolved forever. The mirror case, three words merged into one (`I yield Thee`
→ `he`), is handled by the audio-clock test but only indirectly.

**Fix direction:** allow the alignment to consider a merge of two adjacent
spoken tokens against a single reference word.

## 6. `replaceHidden` leaves stale state

It resets `attempts` but not `matched`, `missed`, `frontier`, `judged`,
`unexplainedSinceProgress` or `misses`. A word un-hidden and re-hidden within a
session reads as already resolved, and `misses` retains records for words that
are no longer hidden — those records feed `expectedCount` and the recitation
log. One caller, in `VoiceRecitationController`.

## 7. A lone token can still match a distant word

Reference deletions before the first spoken token are free (`cost[0][column]`
is left at zero), which is what lets a reciter resume mid-passage. Combined
with the horizon now often spanning the whole passage, a single spoken word can
match a hidden word anywhere in the text. Saying just "myself" against the
dummy passage matches its final word.

The damaging half of this — that same token condemning everything before it —
was fixed on 2026-08-12 by requiring corroboration. What remains is a spurious
*match*, which is far less harmful and is bounded by the reciter actually
having said something that sounds like the word.

**Fix direction:** if it proves to matter, require corroboration for a match
that lands far beyond the frontier, in the same spirit as the moved-on test.

## 8. Efficiency

None of these are hot enough to matter today — alignment measured 8–18 ms per
result on device — but they are all avoidable:

- `Set(hiddenIndices)` is rebuilt on every ingest; it changes only in `init`
  and `replaceHidden`.
- `anchors(around:)` is computed twice for every condemned candidate, once via
  `unheardSpan` and once via `tokens(displacing:)`.
- `align` rebuilds the full spoken × reference match matrix on every result.
  With the horizon frequently spanning the whole passage this is now O(n²) per
  result rather than bounded by a small window.
- `PhoneticKey.encode` allocates a filtered `String` on every call purely to
  test whether the token is the literal `"0"`.

## 9. Housekeeping

- `RecitationCapture` writes one `.wav` per recitation to the documents
  directory and never prunes. Fifty-odd files, tens of megabytes, accumulated on
  the development device. Every call site is correctly `#if DEBUG`, so nothing
  ships, but the debug device fills up.
- `RecitationLanguageModel.builds` is never evicted: one retained `Task` per
  distinct passage for the lifetime of the process.
- `RecitationMatcher.seconds(_:)` sits in the middle of the static constant
  block, splitting the constants in two.

---

## Fixed on 2026-08-12

Recorded here because the reasoning is easy to lose and each was verified on
the device or by offline replay of a captured trace.

- **Verdicts followed finalization, not speech.** The transcriber finalized five
  times in a 53-second recitation, twice with gaps near twenty seconds, and the
  moved-on sweep only ran on final results. Volatile results now run the sweep
  with a wider margin, because replaying a trace at the settled margin of 2
  produced three false misses while 4 and above reproduced the settled verdicts
  exactly.
- **A garbled transcript was reported as the reciter's error.** A miss now
  requires an empty slot; unaligned transcriber output in the slot means the
  evidence is about recognition, not the reciter. Twelve misses became two on
  the same recitation.
- **An emptied slot was read as proof of a skip.** The transcriber merging
  `I yield Thee` into `he` empties the slot just as a real skip does. The runs
  already carried `audioTimeRange` and the tokens discarded it; a miss now also
  requires the anchors to sit back to back.
- **The stuck-word escape hatch could never open.** Volatile results withhold
  their last token from judgement but `judged` advanced to the full spoken
  count, so the next result always found an empty range and
  `unexplainedSinceProgress` stayed false. Across six device runs it went true
  four times in 926, and the attempt budget never once incremented.
- **Reciting only the hidden words could not work.** Skipping a reference word
  cost the same whether it was hidden or plain text, so the aligner preferred to
  stop rather than reach across untouched words, and a word could be spoken and
  transcribed perfectly and still never register. Skipping a visible word is now
  free while hidden words still cost, and the horizon counts hidden words rather
  than raw ones.
- **A stray word condemned everything before it.** The free visible skip let a
  single token anchor deep in the passage; saying "banana" once recorded four
  misses. A miss now requires at least two aligned reference words after the
  candidate.
- **Vowel onsets waived the consonant check.** `sharesOnset` returned true
  whenever *either* key began with a vowel, so `banana` matched `on` and, more
  seriously, `I` matched `Thy`. Onsets must now agree on being vowels, and two
  consonants must still be equal. On a real Family Prayer transcript this
  removed three matches, all of them archaic pronouns being satisfied by a
  vowel-initial word — false passes, not lost credit.
