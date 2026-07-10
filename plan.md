# Scripture Memorization App — Plan

## Core idea

A looping review queue, applied to scripture recitation. The design uses **one entity type and two functions** — no hierarchy, no separate "passage-level" logic, no parent/child relationships. Target platform: native iOS, minimum iOS 17.

Cards are always presented in scripture order. The queue cycles through them front to back and loops indefinitely. Grading is self-reported: the user picks from five hide outcomes (reveal 2, reveal 1, no change, hide 1, hide 2), a superset of Anki's grade idea. There is no time dimension and no priority — grade determines only how much of the card is hidden, never its position in the queue.

## The core mechanic: hide + merge

**This is what makes the tool different.** Everything else in this plan — Anki-style grading, the looping queue — is borrowed from existing practice. Hide + merge is the part that's original to this tool, and it's the part that actually solves the sequential-recall problem Anki's model can't handle on its own.

The ladder works like this:

1. **Hide** — within a single card, demonstrating retention progressively hides more of that card's leading text. The user starts reading the full text, and over successive successful reviews ends up reciting it from memory, with nothing shown.
2. **Merge** — once two *adjacent* cards are both fully hidden, they combine into one new, larger card spanning both. The merged card starts over completely: fully visible text, `hiddenWordCount` reset to 1, back through the introduction gate. Reciting the combined span is treated as a distinct skill from reciting its two parts — it has to prove itself independently, scaffolding included.
3. **Repeat** — the merged card is hidden again, and merges again with its neighbor once it too is fully hidden. This repeats indefinitely.

The effect: chunk size isn't decided up front by a curator's guess — it emerges naturally from actual performance. A passage isn't "done" via a separate flag or status field; it's done when the ladder has collapsed it down to a single card spanning the whole passage. No card, atomic or merged, is ever retired — the queue just keeps cycling, the same way real retention never truly locks at 100%. Reaching that single-card state gets no special UI treatment — the card just keeps getting reviewed like any other.

## Data model

```
Passage = { id, title }                         // immutable, written once at import

Reviewable = {
  passageRef,
  span: { start, end },                          // anchored to original unit numbering, fixed forever
  expectedText,                                  // text to recite for this span
  hiddenWordCount,                               // leading words currently hidden from the prompt; floor is 1
  isIntroduced: Bool                             // false = not yet in rotation; true = actively reviewed
}

// User-configurable via Settings: QUEUE_SIZE.
```

- `span` numbering is assigned once at import and never renumbered, even as cards merge.
- No tree, no list of children, no stored `Passage` contents. Order and completion status are derived on demand — never stored redundantly.
- There is no due date, no scheduling state, no priority, no time dimension of any kind. Queue order is always span order.

## Core functions

```
render(card) = card.expectedText with its first `hiddenWordCount` words blanked —
               each hidden letter becomes "_", punctuation stays visible ("O God!" → "_ ___!")

presentCard(card):
  show card.expectedText in full
  user taps anywhere to begin hiding
  the leading hiddenWordCount words blank out one at a time — a left-to-right
    "domino," each word snapping to underscores in lockstep with a crisp haptic tick
  // settles into render(card) — the prompt the user attempts against

revealAnswer(card):
  the hidden words reappear with the same left-to-right domino (and haptic ticks),
    but quicker than the hide — ephemeral, display-only; never changes hiddenWordCount
  then present the five grade buttons (reveal 2 / reveal 1 / no change / hide 1 / hide 2)

attempt(cards, cardID, grade):                   // returns the updated card array
  // grade drives the hiding ONLY — it never reorders the queue
  // each grade reveals (+) or hides (−) a fixed number of words next time:
  //   Again +2 shown, Hard +1 shown, Same 0 (no change), Good −1 shown, Easy −2 shown
  // hiding is the inverse of revealing; floor 1, ceiling wordCount
  newHidden = clamp(card.hiddenWordCount − wordsRevealedDelta(grade), 1, card.wordCount)
  return cards with card updated: hiddenWordCount = newHidden

  // nextHidden(grade, card) wraps this clamp as the single source of truth — the grade
  // button preview and the actual grade both call it, so they can never drift

queue(cards) = cards.filter { isIntroduced }.sortBy(span.start, ascending)

adjacent(a, b)     = a.span.end + 1 == b.span.start
fullyHidden(card)   = card.hiddenWordCount >= wordCount(card.expectedText)

fillQueue(cards):                                // idempotent; called after every grade and at import
  while queue(cards).count < QUEUE_SIZE and there are unintroduced cards:
    introduce next unintroduced card (lowest span.start): isIntroduced = true

introduceAll(cards):                             // introduces every card; called at session start
  set isIntroduced = true on every card

mergeCheck(cards):
  sorted = cards.sortBy(span.start)
  for each adjacent (a, b) where fullyHidden(a) and fullyHidden(b):
    replace pair with merged card:
      span: { a.span.start, b.span.end }
      expectedText: a.expectedText + " " + b.expectedText
      hiddenWordCount: 1
      isIntroduced: false                        // re-enters introduction gate
    discard a, b
  fillQueue(result)
```

**Computed values — do not store these as fields:**
- Sequence → `activeCards.sortBy(span.start)`
- Current card → `queue[step mod queue.length]` — the cursor advances one per grade and loops
- Passage fully learned → `activeCards.length == 1`
- Card fully hidden → `hiddenWordCount >= wordCount(expectedText)`
- Card display label → `"Unit " + span.start` (or `"Units " + span.start + "–" + span.end` once merged)
- Passage progress → `N − activeCards(passage).length` of `N` "merged," where `N = max(activeCards(passage).map(c => c.span.end))`
- Queue position label → "1 of N" — position within one cycle of the queue (step mod queue.length + 1)

## Import

Boundaries are explicit input, not inferred output. No NLP or heuristic clause-splitting — the curator controls chunking by how the pasted text is formatted: **one memorization unit per line.**

```
createPassage(import: { title, units: string[] }):
  passage = Passage{ id: new(), title }
  cards = []
  for i, text in enumerate(units):
    cards.append Reviewable {
      passageRef: passage.id,
      span: { i+1, i+1 },
      expectedText: text,
      hiddenWordCount: 1,
      isIntroduced: false
    }
  fillQueue(cards)                               // seeds the initial queue up to QUEUE_SIZE
```

The curator is told explicitly: one unit per line; strip out line breaks that aren't true boundaries (e.g. word-wrap from a pasted PDF) before importing. No in-app preview or validation step. A bad import isn't destructive — fix the source text and re-import.

## Library

```
listPassages()           // backs the Library screen
deletePassage(passage)   // removes the passage and all its Reviewables; irreversible
```

Title is fixed at import. No text-editing on existing units — the correction path is delete + re-import.

## Session flow

1. **Import** — passage seeded as N atomic `Reviewable`s, each starting with `hiddenWordCount = 1` and `isIntroduced = false`. `fillQueue()` immediately introduces up to `QUEUE_SIZE` cards.
2. **Pick a passage** from the Library screen. Review is scoped to one passage at a time.
3. **Session start** — `introduceAll()` puts every card in rotation. The queue is the full passage in span order.
4. **Review loop** — pull `queue(passage)`; the current card is `queue[step mod count]`. `presentCard` shows the full text; the user taps anywhere when ready, then it blanks the leading `hiddenWordCount` words one at a time — a left-to-right domino, each word snapping to underscores with a crisp haptic tick. The user attempts recitation, then taps anywhere to reveal the answer — the words reappear with the same left-to-right domino, quicker than the hide — and grade buttons appear in one action. The user taps a grade; `attempt()` advances how much is hidden, and the cursor moves to the next card in span order, looping at the end.
5. **After each grade** — `mergeCheck()` collapses any adjacent, fully hidden pairs into one larger card that re-enters the introduction gate; `fillQueue()` refills any freed slots.
6. **Repeat indefinitely.** The queue loops — no card is ever retired. The user exits by tapping "Library" in the nav bar.

## Architecture

- **Persistence:** local-only. No iCloud sync in v1. Single JSON file in the app's Documents directory.

## Design rationale

### Hide + merge

| Choice | Why |
|---|---|
| `hiddenWordCount` is the only per-card review state | Order is fixed by `span`; nothing else needs to be stored to capture how much of the prompt is shown |
| Hidden words removed from the beginning; each grade reveals/hides a fixed count (0, ±1, or ±2 words) | Matches the "vanishing cues" memory-rehabilitation technique; a five-way grade (including a no-change option) gives finer control than a single ±1 step and lets each button preview a distinct outcome. Proportional step (fraction of card length) added complexity without proven benefit at this stage |
| `hiddenWordCount` floor is 1, not 0 | Passive reading (fully visible text) is not a valid review state; the user always attempts from at least one hidden word |
| Grade drives the hiding only, never the order | One user input, one consumer; cards stay in scripture order so the sequence itself is rehearsed |
| Full text shown until the user taps to begin, then the hidden words blank out one at a time as a haptic domino — and reappear the same way, faster, on reveal | Letting the user set their own pace, rather than a fixed reading timer, respects that reading speed varies by passage and person; toggling words sequentially (each with a crisp, punchy haptic tick) is more tactile and playful than a single smooth dissolve, and reads as deliberate rather than text simply vanishing. One left-to-right effect, reused for both hide and reveal, keeps it coherent |
| Revealing the answer never changes `hiddenWordCount` | The hidden state must reflect the user's own grade, not the act of checking the answer |
| Queue loops indefinitely — no card is ever retired | There is no state in which a card is "done" |
| Merged card starts with `hiddenWordCount = 1` and `isIntroduced = false`, re-enters the introduction gate | Reciting a combined span is a distinct skill — must prove itself independently |
| Merging discards its two inputs and produces one flat record | No later need to reference the original pieces |
| Span numbering is fixed at import and never renumbered | A span never needs to change when other cards merge elsewhere |
| No merge lineage stored | Nothing in v1 needs to reconstruct a card's ancestry |
| Single-card "fully learned" state gets no special UI | Emergent property of the ladder, not an event to announce |

### Scheduling & grading

| Choice | Why |
|---|---|
| Fixed scripture order instead of FSRS or a priority queue | Sequential recall — reciting in order — is the skill being trained. Showing cards in their scripture order reinforces the sequence; reordering by difficulty (an earlier priority-queue design) worked against it. No time dimension either: the goal is fluency from repetition, not optimizing intervals against a forgetting curve |
| Self-reported grade (five hide outcomes: reveal 2 / reveal 1 / no change / hide 1 / hide 2) | Proven, familiar; avoids building an automated grading pipeline in v1 |
| Grade maps to the hiding only, by a fixed per-grade word count (Again +2 / Hard +1 shown, Same 0, Good −1 / Easy −2 shown) | One input, one consumer; nothing about ordering depends on the grade |
| Tap to reveal answer and grade buttons in one action | Mirrors Anki's "Show Answer" — no new gesture |
| All cards introduced at session start (`introduceAll`) | No per-day gate needed without a time dimension; the queue size is the natural workload control |
| `QUEUE_SIZE` caps cards in rotation | Prevents a large import from overwhelming the queue; replaces Anki's new-card-per-day limit |
| Grade buttons show only their hide-effect preview ("Show 2", "Hide 1", "No change") — no Again/Hard/Good/Easy text label — instead of Anki-style intervals | There is no time dimension to show, but the hide delta is the equivalent forward-looking cue — it tells the user what each grade will do to the prompt next time, so the named label is redundant. Clamped via `nextHidden`, so a grade that can't change the prompt (already at floor/ceiling) shows "No change", same as the dedicated no-change button |

### Import & data model

| Choice | Why |
|---|---|
| Unit boundaries from curator-formatted text, not NLP | Heuristic splitting is unreliable and a wrong split isn't auditable |
| Import contract is documented, not enforced in-app | A bad import is non-destructive — fixed by correcting the source and re-importing |
| Display labels derived from `span` | No extra required input at import; stays correct automatically through merges |
| No ordering field in `Reviewable` | `span` gives the order and `isIntroduced` gates rotation — no priority, difficulty, stability, due date, or last-review date |

## Future directions

- **Automated speech-based grading** — on-device speech recognition (e.g. Apple's SpeechAnalyzer) replacing or augmenting the manual grade tap. Audio never leaves the device.
- **Live word-level feedback** — highlighting words correct/incorrect in real time as speech is recognized.
- **Domain vocabulary handling** — reliable recognition of scripture-specific terms and proper nouns within an automated matching approach.
- **Rolling retention stat** — a 30-day window version could be diagnostic in a way a lifetime average isn't. Dropped from v1 as premature.
- **Streak / AppStats** — a current-streak counter was designed, then cut to keep v1 minimal. Worth revisiting if users want a basic engagement signal.
- **Notifications** — a daily local reminder was scoped in, then cut. No permission flow in v1.
- **Edit passage text** — redundant with delete + re-import, which is already the documented correction path. Could be added if re-import proves cumbersome.
- **Onboarding explainer for hide + merge** — the mechanic is non-obvious. First cut to revisit if early users seem confused.

## Open items

- **Per-grade hide deltas** — currently fixed (Again/Hard +2/+1 shown, Same 0, Good/Easy −1/−2 shown); a proportional step (fraction of card length) was designed but dropped pending real usage data
- **QUEUE_SIZE default** — currently 10; tune with data. Note: `introduceAll` introduces every card at session start, so `QUEUE_SIZE` currently only bounds the queue at import time, not during a session — revisit whether sessions should respect it
- **Merge group size** — strictly pairwise, or allow 3+ adjacent ready cards to merge at once
- **(Future only)** automated grading thresholds and vocabulary handling
