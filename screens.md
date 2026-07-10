# Scripture Memorization App — Screens

## Navigation

No tab bar. Library is the root screen. No global Review entry point — review is always entered per-passage by tapping a row.

- Library nav bar: leading gear icon → Settings; trailing "+" → Import.
- All other screens: leading back chevron ("Library").

## Library

The root screen. Shows a practice-streak card above all imported passages.

- **Nav bar:** gear (Settings) / "Library" / + (Import)
- **Practice streak card:** day-streak count beside a strip of the last 7 days — each dot's fill deepens with how many words were hidden that day; today shows a solid outline until practiced. Below a divider, a suggested chunk with a "Practice this chunk" button that opens its session — chosen by `StreakTargetPicker`: walk passages from most to least recently practiced (then never-practiced, alphabetically) and take the first passage's earliest incomplete chunk (first not fully hidden); if every passage is complete, a chunk picked at random for the day. Hiding any word today completes the day: the card shrinks to just the streak info (glowing, count in accent, today's dot filled) and the chunk prompt disappears until tomorrow. A day with no hidden words breaks the streak; hidden state is never gated by it.
- **Rows:** passage title + progress fraction (e.g. "3 of 8 merged") + muted chevron. Sorted alphabetically by title.
- **Tap a row** → enters that passage's Review Session.
- **Swipe left** → reveals "Delete" (red). Confirmed before deleting. No rename — title is fixed at import.
- **Empty state:** "No passages yet. Import one to get started."
- **Native note:** use SwiftUI `.swipeActions()`, not custom gesture code.

## Import

A full push screen, not a modal sheet.

- **Nav bar:** "Library" / "Import" / "Import" (disabled until valid)
- **Components, top to bottom:**
  - Title field — single line, sans, system row style, placeholder "Title"
  - Helper caption — sans, muted: "One verse per line. Remove line breaks that aren't real boundaries — like word-wrap from a pasted PDF — before pasting."
  - Scripture text area — serif, multi-line, placeholder demonstrates the one-unit-per-line format with generic example text. Soft gradient at the bottom edge.
- **Validation:** Import button enables only when title and content are both non-empty (trimmed). No content-correctness checking — the curator is responsible for correct line formatting.
- **On confirm:** creates the passage and its Reviewable cards, returns to Library, new passage appears at the top.

## Review Session

Entered by tapping a passage row in Library. Scoped to that passage's queue only.

- **Nav bar:** "Library" / passage title (no trailing action)
- **Progress:** "1 of 3" text below the nav bar, sans, muted — position within one cycle of the queue
- **Card flow:**
  1. Full text shown in serif. User taps anywhere when ready to begin hiding.
  2. Leading `hiddenWordCount` words blank out one at a time — a left-to-right "domino," each word snapping instantly to underscores in lockstep with a crisp, punchy haptic tick. Each hidden letter becomes an underscore ("_"), one per letter, with punctuation left visible ("O God!" → "_ ___!"). Hidden words render in the same `Theme.ink` color as visible text (no opacity, no `hairline`), with extra kerning between the underscores so the blanks read clearly. Bottom-edge gradient. Hint text: "Tap when you're ready to check."
  3. User taps anywhere → the hidden words reappear with the same left-to-right domino and haptic ticks, but quicker than the hide, then the grade buttons appear below (Anki's "Show Answer" in one tap).
  4. User taps a grade → `attempt()` runs; next card begins. Queue loops indefinitely.
- **Grade buttons:** five equal-width buttons, color-coded. They carry no Again/Hard/Good/Easy text label — each button shows only its hide-effect preview, the equivalent of Anki's interval labels: "Show 2" / "Show 1" for the two reveal-more grades, "Hide 1" / "Hide 2" for the two hide-more grades, and a neutral "No change" button in the middle that leaves the prompt as-is. "No change" is also what any button reads when clamping means the prompt can't change.
- **No end state.** The queue loops. User exits by tapping "Library" in the nav bar.
- **Native note:** card flow is wired to `queue()`, `attempt()`, `mergeCheck()`, and `introduceAll()` (called once at session start).

## Settings

A full push screen from Library.

- **Nav bar:** "Library" / "Settings" (no trailing action — changes apply live, no Save button)
- **Two rows**, each with a label, control, and short caption explaining the tradeoff:

| Setting | Control | Default | Caption |
|---|---|---|---|
| Queue Size | Numeric stepper (step 1) | 10 | How many cards are in rotation at once. New cards enter the queue as cards merge. |
| Reading Time | Numeric stepper (step 50 ms) | 200 ms/word | How long each word is shown before the words start hiding. Lower is faster. |

- **Native note:** use SwiftUI `Stepper` directly.

## Out of scope for v1

- Onboarding / first-run explainer
- Passage detail screen
- Passage text editing (correction path is delete + re-import)
- Passage rename (title is fixed at import)
- Notifications / due-review reminders
- Dark mode
- Accessibility beyond iOS platform defaults
- Import validation or preview UI
- Streak / stats header on Library
