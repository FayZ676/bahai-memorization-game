# Scripture Memorization App — Design

## Philosophy

The visual system is grounded in the app's own mechanic — fading text as a measure of memory — not in manuscript or devotional tropes. Warm cream background + serif display + terracotta/gold accent is the current default for anything "old text, scripture." This system uses a cooler palette and ties its one accent color and signature motif to what the app actually does.

## Color tokens

| Token | Hex | Role |
|---|---|---|
| `bg` | `#F6F7F5` | Background — cool mist |
| `ink` | `#16211F` | Primary text — deep teal-black |
| `muted` | `#6E7572` | Secondary text, captions |
| `accent` | `#2F6F62` | Primary actions — the one signature color |
| `accentMuted` | `#B9BEBA` | Disabled state of accent elements |
| `hairline` | `#E1E3DF` | Dividers, borders |
| `rowBg` | `#FFFFFF` | List rows, input rows — lifted above `bg` |

## Typography

Two roles, split by what the text *is*, not by screen:

| Role | Family | Applies to |
|---|---|---|
| Content being memorized | `ui-serif` (New York on Apple devices), Georgia fallback | Scripture text fields only — the Import paste area, the Review recitation prompt |
| Everything else | `-apple-system, system-ui` (SF Pro) | Nav bars, buttons, captions, labels, the passage Title field |

The Title field is sans because it describes the content — it isn't the content.

## Signature element

A soft gradient at the bottom edge of any serif text field, dissolving to `bg`. Used only where scripture content appears. It foreshadows the app's hide mechanic — the one deliberate visual choice; everything else stays restrained.

## Grade button colors

Used only in Review Session, for the self-assessment buttons. Five grades form a spectrum
from "show me more" to "hide more", each labeled with the concrete change it makes to the
prompt next time (`Show n` / `Keep` / `Hide n`):

| Grade | Action | Color |
|---|---|---|
| Again | Show 2 | `#B3473D` (red) |
| Hard | Show 1 | `#C8862F` (orange) |
| Same | Keep | `#6E7572` (grey — reuses `muted`) |
| Good | Hide 1 | `#2F6F62` (green — reuses `accent`) |
| Easy | Hide 2 | `#3B6FA0` (blue) |

Each button is color-coded *and* labeled. Color alone isn't enough.

Only buttons with a distinct, achievable outcome are shown. At the extremes the reveal range
clamps — when the card is fully hidden you can't hide more, when fully shown you can't show
more — so grades that would collapse to the same result are dropped rather than rendered as
duplicate buttons. `Same` always keeps the grey no-change slot.

Labels are kept short and uniform in length (the neutral grade reads `Keep`, not `No change`)
so that five equal-width buttons stay balanced, and each button carries internal horizontal
padding so text never reaches its edges — important on smaller devices where five buttons
share a narrow row. Every label stays on a single line, so all buttons share one height.

## Deferred

- Dark mode color and type mapping.
