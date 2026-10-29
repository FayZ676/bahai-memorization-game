# Recitation bench — the spec every recitation design must pass

Agreed 2026-10-27. The bench exists before any solution is chosen. A candidate design is
judged only by this document; nothing is built on reasoning about how speech recognition
"should" behave.

## The one rule about truth

What was said is never decided by a recognizer — not Apple's, not ours. Truth comes from:

1. **The script card**, written before the take is spoken ("say *my* instead of *Thy* in
   'to Thy might'"). Its labels exist before any audio does.
2. **The reciter listening back** to the audio and tapping any word they slipped on, on
   the passage text. The review screen never shows a transcript.

Takes are raw audio, recorded in the app on the iPhone through the same microphone path
recitation uses (16 kHz mono, `.record` / `.measurement`). Every candidate — the current
Apple pipeline included — is re-run from that audio and its output is graded against the
truth. Its output is never the truth.

## Scope

- **Voice:** Faizi, at his normal reciting pace. Other voices come later.
- **Passages:** the Short Obligatory Prayer (*SOP*) and the Family Prayer that opens
  "I beg Thy forgiveness, O my God" (*FAM*). Their texts are built into the bench
  (`BenchPrayer`), independent of how the library chunks them.
- **Unit:** one take recites the whole prayer.

## Pass bar

Scored per take, per hidden configuration (below).

| Outcome | Requirement |
| --- | --- |
| A hidden word the truth says was said correctly is credited by the end of the take | **100%** — a single miss fails the bench |
| A hidden word the truth says was said wrong (swapped, skipped) is credited | **never** |
| Fillers, silence, restarts credit anything that was not said | **never** |
| Seconds from the end of a word to its credit | recorded, not yet a gate |

A word said correctly after a self-correction counts as said correctly.
A word said twice (restart) is owed credit once.

## Hidden configurations

The audio does not depend on what was hidden, so every take is replayed under all of these
at no recording cost:

- **all** — every word hidden
- **each** — one word hidden, once per word in the prayer
- **scattered** — every third word
- **ends** — first and last word only
- **run** — a contiguous run of five words from the middle

## Takes

All at normal pace, quiet room, phone held as usual, unless the card says otherwise.
*Per prayer* means for each of the two prayers.

### SOP — 19 takes

| ID | Card | Takes |
| --- | --- | --- |
| C1 | Recite as written. | 3 |
| C2 | Start speaking the instant you tap. | 1 |
| C3 | Somewhere mid-prayer, stop for 3–8 seconds as if recalling, then continue. | 2 |
| C4 | Partway through, go back to the start of the sentence and say it again. | 1 |
| C5 | Say "um" or "uh" once mid-prayer. | 1 |
| C6 | Start from the sentence nearest the middle, not the beginning. | 1 |
| S1 | "to Thy might" → say "to **my** might" — *Thy* not credited | 1 |
| S2 | "to know Thee" → say "to know **me**" — *Thee* not credited | 1 |
| S3 | "that Thou hast created" → say "that Thou created" — *hast* not credited | 1 |
| S4 | "to Thy wealth" → say "to Thy **health**" — *wealth* not credited | 1 |
| S5 | Leave out "the Help in Peril," — those four words not credited | 1 |
| S6 | Say "to my might — to Thy might" — *Thy* credited | 1 |
| E1 | Fan or air conditioning running | 1 |
| E2 | TV or music playing quietly in the room | 1 |
| E3 | Phone flat on a table at arm's length | 1 |
| E4 | Speaking through AirPods | 1 |

### FAM — 7 takes

FAM is three times longer, so its takes are consolidated. SOP already covers delivery and
environment; FAM adds the archaic vocabulary. Several deviations share one take — each sits
in a different phrase, and several slips in one recitation is the harder, more realistic case.

| ID | Card | Takes |
| --- | --- | --- |
| C1 | Recite as written. | 2 |
| C24 | Start the instant you tap; partway through, restart a sentence. | 1 |
| C35 | Pause 3–8 seconds mid-prayer; say "um" or "uh" once elsewhere. | 1 |
| C6 | Start from the sentence nearest the middle. | 1 |
| FD1 | "befitteth **my** Lordship" (*Thy* not credited); leave out "my parents" (not credited); "well **befitteth** the glory" (*beseemeth* not credited); "reveal myself — Thyself unto me" (*Thyself* credited) | 1 |
| FD2 | "as Thy Lordship" (*befitteth* not credited); "I **give** Thee praise" (*yield* not credited); "reveal **myself** unto me" (*Thyself* not credited); "my duty to know **me**" (*Thee* not credited) | 1 |

## Recorded set (2026-10-27)

25 takes: all 19 SOP takes, and 6 of the 7 FAM takes (FD2 was not recorded, so FAM's
*myself*/*Thyself* and *give*/*yield* swaps are untested; SOP's *my*/*Thy* and *me*/*Thee*
swaps still cover meaning-changing pronouns).

## Apple baseline (current pipeline), everything hidden

| Prayer | Correct words credited | Wrong words credited |
| --- | --- | --- |
| SOP | 76.8% (724 / 943) | 4 |
| FAM | 46.4% (362 / 781) | 37 |

Of the 638 misses across both, 292 were never produced by Apple as the written word and
346 were heard exactly but not credited by `RecitationMatcher` — on FAM the matcher loses
its place and drops whole paragraphs.

## Recording mode (debug builds only)

- Pick a prayer; the card for the next take is shown above its text.
- Record keeps the microphone on until Stop — nothing auto-stops it.
- After Stop: play the take back against the passage text, tap any word slipped on, save.
- Each take is saved to Documents as `bench-<ID>-<stamp>.wav` and a `.json` beside it:
  prayer, words, card ID, the word indices the card deviates on, and the reciter's marked
  slips.

## Running candidates

- **Mac** — any candidate that runs off-device replays every take and prints the scorecard.
- **iPhone** — the debug Recitation Bench screen replays saved takes through the bundled
  model and any candidate `*.mlmodelc` in `Documents/Bench`, writing each window's output
  beside the take for the Mac to score; `BENCH_LIVE=1` runs the app's own live engine over
  every take.

The Apple pipeline was scored first, as the baseline; it has since been removed from the app.

## Candidate 1 — acoustic alignment against the known text (2026-10-27)

`candidates/ctc_align.py` + `candidates/evaluate.py`, offline on the Mac, whole-file.
wav2vec2 large (LV-60k, 960h LibriSpeech, character CTC, no language model) gives letter
probabilities every 20 ms; a Viterbi path follows the prayer with a garbage state between
words, cheap skips only before the first spoken word, costly skips elsewhere, and jumps back
for restarts. A word is credited when its best occurrence has every letter fitting
(per-letter score ≥ threshold).

| | Apple pipeline | Candidate 1 (threshold −5) |
| --- | --- | --- |
| Correct words credited | 1086 / 1724 (63.0%) | 1719 / 1724 (99.7%) |
| Wrong words credited | 41 | 0 |

Every wrong word scores ≤ −10.0; any threshold from −5 to −10 credits none of them.
Remaining misses: E4 (AirPods, not yet gated) ×2; FAM C1 "and I beg Thee" (both
recognizers hear no "I" — likely an unmarked slip, to be checked by ear); "transcendent"
heard as "TRANS SEND THEM"; "forgive" heard as "FORTIVE".

Not yet tested: streaming (live, chunked) inference instead of whole-file, and running the
model on the iPhone (Core ML size, speed, latency).

```sh
python Tools/RecitationBench/candidates/ctc_align.py Tools/RecitationBench/takes \
  --model WAV2VEC2_ASR_LARGE_LV60K_960H --out result.json
python Tools/RecitationBench/candidates/evaluate.py Tools/RecitationBench/takes result.json --threshold -5
```

### Model size vs accuracy (threshold −5, all 25 takes)

| Model | Weights | Correct words credited | Wrong words credited |
| --- | --- | --- | --- |
| Large, 32-bit | 1262 MB | 1719 / 1724 | 0 |
| Large, 8-bit (dynamic, Linear layers) | 355 MB | 1720 / 1724 | 0 |
| Base, 32-bit | 378 MB | 1643 / 1724 | 1 |

The app today is 13 MB. 4-bit compression (~180 MB) is untested.

## Candidate 2 — own-voice template matching (2026-10-27)

`candidates/dtw_align.py`. One clean C1 take per prayer is the reference reading; every other
take is aligned to it with the same Viterbi (garbage, skips, restarts) over 20 MFCC + deltas,
normalized per recording; a word scores by how much worse its match to the reference is than
the best match anywhere in the reference, judged on its worst ~50 ms slice. No model; the
whole bench runs in ~6 s.

Rejected: meaning-changing swaps are inseparable from correct speech. *my/Thy*, *me/Thee*,
*health/wealth*, *befitteth/beseemeth* score −0.34 to −0.61; correct words range down to
about −1.0. Best trade-offs: 92% credited with 2 wrong words through, or 99% with 9. Skips
are partly caught. A one-consonant difference does not move a whole-sound fingerprint enough;
distinguishing it is what a trained acoustic model is for.

## Candidate 3 — small trained models: NVIDIA Conformer-CTC (2026-10-27)

`candidates/nemo_align.py` (needs `nemo_toolkit[asr]`): same aligner as candidate 1, with the
model's 1024 word pieces in place of letters ("every piece must fit"); 40 ms frames.
Whole-file, all 25 takes.

| Model | Params | Size (8-bit) | Correct credited, 0 wrong | Lowest correct / highest wrong |
| --- | --- | --- | --- | --- |
| Conformer-CTC medium, 32-bit | 30.8M | 123 MB (fp32) | **1724 / 1724** | −7.10 / −7.97 |
| Conformer-CTC medium, 8-bit | 30.8M | **45 MB** | **1724 / 1724** | −7.41 / −7.93 |
| Conformer-CTC small, 8-bit | 13.2M | 20 MB | 1707 / 1724 | — (overlap) |
| wav2vec2 large, 8-bit (candidate 1) | 315M | 355 MB | 1720 / 1724 at −5 | — (overlap) |

Medium is the first candidate to separate every correct word from every wrong word. Caveats:
the gap is narrow (0.52 at 8-bit), the threshold sits where it does because these results
were seen, the lowest "correct" word is the FAM C1 "and I beg" that every recognizer hears
without "I" (likely an unmarked slip; if so the gap widens), one speaker, whole-file rather
than live, and nothing has run on the iPhone yet.

### Medium, live (8-bit, 6 s window, 1 s hop, 1 s lookahead, credit after 2 confirming words)

Threshold fixed in advance at −7.67 (midpoint of the whole-file gap): 1715 / 1724 correct
credited (99.5%), 2 wrong credited, credit lag median 2.2 s / p90 2.9 s. Both wrong credits
are premature commits on ambiguous phrases (FAM C6 "O my God" occurs in both paragraphs;
FD1 an intermediate alignment placed "Thy"); the misses are short words near window seams.
The model holds up; the live commit rule is what needs work.

### Medium, live — evidence commit (2026-10-27)

Settings fixed before the run: threshold −7.67; 6 s window, 1 s hop, 0.5 s lookahead; window
holds only audio heard so far; frames refreshed by every later window except its first 2 s
(2 s chosen label-free, by closeness of live frames to whole-file frames); one flat cost of 20
for starting anywhere but the first word; a word is committed when removing it worsens the
best alignment by ≥ 5, never taken back; the final alignment at stop commits the rest.

| Model | Correct credited | Wrong credited | Lag median / p90 |
| --- | --- | --- | --- |
| Medium, full precision | 1723 / 1724 (miss: E4 AirPods "Thou") | **0 / 103** | 1.2 s / 1.6 s |
| Medium, PyTorch dynamic 8-bit | 1723 / 1724 | 1 (S1 "Thy" at −7.51) | 1.2 s / 1.7 s |

Full precision is the right stand-in for the phone: Core ML stores 8-bit weights but computes
in 16-bit, unlike PyTorch's dynamic mode, which also quantizes activations. Every gated card
passes. Margin is thin: weakest correct words (−7.25 to −7.45, mostly "bear") sit close to
−7.67. Next: Core ML conversion and replaying the bench on the iPhone.

### Medium on the iPhone — Core ML (2026-10-29)

`candidates/coreml_convert.py` converts medium into one Core ML pipeline: 6 s of 16 kHz audio
in, 150 frames × 1025 log-probabilities out. The mel front end is rebuilt as a fixed conv1d
DFT (matches NeMo's preprocessor to 4e-6) and kept in 32-bit; the encoder and decoder run
16-bit. Two builds: 16-bit weights (68 MB compiled) and 8-bit weights (35 MB).

Two traps, both fixed in the converter and the bench screen:

- **16-bit overflow on quiet windows.** NeMo scales the subsampler output by √256 = 16 before
  layer 0; on a window that is mostly silence, per-feature normalization makes the few speech
  frames huge and the residual stream reaches 71,122 — past 16-bit's 65,504. CPU/GPU gave NaN,
  the Neural Engine clamped to −45,440. Layer 0 reads its residual only through LayerNorm and
  ends in one, so the converter drops the ×16 and scales layer 0's four output projections by
  1/16 instead: exact in 32-bit, no overflow in 16-bit.
- **Padded output rows.** On the phone the output array's rows are 1040 wide, not 1025
  (strides `[156000, 1040, 1]`); reading it as packed scrambles every frame. The bench reads it
  through `MLShapedArray(converting:)`.

The debug Recitation Bench screen (or launching with `BENCH_CONFORMER=1`) loads every
`*.mlmodelc` in `Documents/Bench`, replays every take through the same live windows as the
Mac (6 s, 1 s hop, 0.5 s lookahead), and writes each window's output (`.<model>.f16`) and its
timing (`.<model>.json`) beside the take. `nemo_align.py --recorded DIR MODEL` scores those
windows with the evidence-commit rule above, unchanged.

Settings as in the evidence-commit run, threshold −7.67, all 25 takes, iPhone 14 Pro,
compute units `.all`:

| Run | Correct credited | Wrong credited | Lag median / p90 |
| --- | --- | --- | --- |
| PyTorch 32-bit, Mac (reference, re-run) | 1723 / 1724 | 0 / 103 | 1.24 s / 1.64 s |
| Core ML 16-bit, iPhone | **1723 / 1724** | **0 / 103** | 1.24 s / 1.64 s |
| Core ML 8-bit weights, iPhone | 1723 / 1724 | 1 (S1 "Thy" at −7.61) | 1.24 s / 1.64 s |
| Core ML 16-bit / 8-bit, Mac | same as the iPhone rows | | |

16-bit on the phone makes the same credit decision as PyTorch on every one of the 1827 scored
words. The miss is still E4 (AirPods) "Thou". 8-bit lets S1's *Thy* through, as PyTorch's 8-bit
did — 16-bit weights are what ships.

| Phone timing | 16-bit | 8-bit |
| --- | --- | --- |
| Per 6 s window, median / p99 / max | 11.1 / 12.4 / 22.1 ms | 10.7 / 12.1 / 17.9 ms |
| First load (on-device compile) | 5.3 s | 6.2 s |

A window costs ~1% of its 1 s hop, so the model is not what limits live latency.

The margin moved, though. Weakest correct words on the phone: *didst* −7.66 (C1, FAM), *bear*
−7.56, *powerlessness* −7.46, against the −7.67 threshold — *didst* clears it by 0.01. 16-bit
arithmetic shifts scores by about ±0.1, which is the same size as the gap between correct and
wrong words (−7.61 is the closest wrong word, under 8-bit).

Not yet tested: the aligner and commit rule running on the phone (they ran on the Mac over
the phone's windows), the 5 s first load, and memory use.

### Live in the app (2026-10-29, debug builds only)

Settings → Debug → **Recite with Conformer** routes session recitation to the Conformer instead
of Apple's recognizer. The model and its vocabulary load from `Documents/Bench`
(`conformer-fp16.mlmodelc`, `conformer-vocabulary.json`, written by `export_vocabulary.py`);
they are not in the app bundle.

The aligner, tokenizer and commit rule are Swift ports (`Logic/ConformerTokenizer.swift`,
`ConformerAligner.swift`, `ConformerTracker.swift`). `Tools/RecitationBench/conformer/main.swift`
compiles them on the Mac: `tokenize` checks every word of the bundled library against Python
(9290 / 9290 match); `replay` runs them over recorded windows. Over the phone's windows the Swift
port credits the same words at the same moments as Python, with identical scores (1827 / 1827).

`BENCH_LIVE=1` feeds every take through the in-app engine in 1024-sample buffers, as the
microphone does: on the iPhone it credits exactly the words the Mac does on all 25 takes. Debug
build (unoptimized), per 1 s hop: median 38–65 ms, worst 195 ms (FAM C24).

Not wired yet: misses and the speech history (a Conformer attempt records nothing), the live
"heard" text, and capturing the audio of live attempts for the bench.

## Shipped (2026-10-29)

Apple's recognizer is gone from the app; the Conformer is the only recitation path, bundled as
`MemorizationGame/Resources/Conformer.mlpackage` (68 MB). Speech History and the recitation record
in Report Issue were removed with it — they were built on Apple's transcript.

Two rules added after the live trial:

- **One stretch of audio credits one word.** Stopping mid-prayer used to let the final pass
  credit later repeats ("but", "in", "the") on audio already used by an earlier word. At stop, a
  word is now credited only on audio after the last live credit, and never on audio another
  credited word already holds. Cost on the bench: 1721 / 1724 correct (two FAM words lose their
  stop-pass credit), still 0 wrong.
- **Wrong-word flash.** When the reciter has reached the owed word, said something, and 2 s of
  quiet pass without a credit, the word flashes and shakes (it stays owed). Never fires on a
  correctly said word in the 25 takes; on takes cut short to stop mid-prayer it catches a wrong
  word then a stop in 4 / 6, a skip-ahead then a stop in 23 / 45, and flashes a correct word in
  21 / 142 (some of these are cutting artifacts).

`candidates/synthetic_stops.py` builds those cut-short takes; `candidates/evaluate_misses.py`
scores flashes. Cut-short takes are a stopgap: real takes of stopping, slipping and skipping
belong in `takes/`, recorded with the Free card and pulled with `pull-takes.sh`.

## The whole prayer, recited from anywhere (2.0)

The session is one scrollable page; reciting starts at a chosen paragraph and runs to the end of
the prayer. Aligning the whole remaining prayer against every second heard would grow without
bound, so `ConformerSession` aligns a 64-word span starting at the chosen word and re-anchors once
24 or more words are behind the last credit: the new span starts 8 words before that credit, with
audio from the end of the word before it, and the missed seconds are replayed window by window so
the new tracker never starts on a gap. More than 45 s without progress keeps only the latest
audio. Until the first re-anchor every window is identical to the bench above.

`conformer/main.swift live` runs the app's own `ConformerSession.listen` with Core ML on the Mac;
takes with a `startIndex` start there, as the app does.

| Run (all 25 takes) | Correct credited | Wrong credited |
| --- | --- | --- |
| Mac, unlimited span (no re-anchoring) | 1720 / 1724 | 0 / 103 |
| Mac, 64-word span | 1720 / 1724 | 0 / 103 |
| iPhone, 64-word span (`BENCH_LIVE`) | 1719 / 1724 | 0 / 103 |

The first version held the anchor behind any earlier uncredited word; wrong or skipped words never
credit, so it stalled until the 45 s limit and lost 167 FAM words with 9 wrong. Holding back only
the last 8 words fixed it. The iPhone differs from the Mac on one word (C6's first word), a
numeric edge; the slowest iPhone hop is 380 ms (a re-anchor catch-up).
