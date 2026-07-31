# Achievement badges

Source of truth for the prompts that generate achievement badge art.

- `badges.json` — every style decision. The data.
- `badges.py` — template substitution, validation, and the CRUD verbs. The code.
- `test_badges.py` — asserts every invalid config is rejected.

```sh
python3 Design/Badges/badges.py list
python3 Design/Badges/badges.py prompt healing 1
python3 Design/Badges/badges.py prompt first_prayer_memorized
python3 Design/Badges/badges.py prompt --all
python3 Design/Badges/badges.py validate
```

The point is determinism. A badge set only reads as a *set* if every badge came out of
the same style anchor, so the anchor lives in one string and the per-badge differences
are a handful of substituted fields. If you find yourself hand-editing a prompt before
pasting it into an image model, that difference belongs in `badges.json` instead.

So: always run the tool and use exactly what it prints. Never write a badge prompt by
hand, never reuse one pasted into a chat or a note, and never tweak one on its way to the
image model. A prompt that did not just come out of `badges.py` is not a badge prompt.
That applies to Claude too — this README is the instruction, there is no skill.

## Layering

Broadest to narrowest, later layers win:

| Layer | Owns | Applies to |
|---|---|---|
| `global` | `finish`, `detail_level` | every badge, always |
| `levels` | default `border` per level | any leveled category |
| `categories.<name>` | `shape`, `icon`, `color` | one category |
| `categories.<name>.levels.<n>` | `label`, `icon_variation`, `overrides` | one badge |

A category with no `levels` key is binary — earned or not — and supplies its own
`border`. Passing a level to it is an error, as is omitting a level for a leveled
category. The generator raises rather than guessing.

Put a change at the broadest layer that is still true. Something true of every badge
belongs in `global`; something true of every level 2 belongs in `levels`.

## Two protected fields

`icon` and `shape` may **never** appear in a level's `overrides`. Validation rejects it
by name, on load *and* on write, and `update` refuses the flags at level scope. This is
the rule that keeps a badge family recognisable as it levels up.

`icon` can still change with level, but only *additively*, via `icon_variation` — the
string is appended to the category icon, never substituted for it. So the compass rose
at level 3 is still a compass rose, with rings of radiating lines around it. That is the
whole visual grammar of progression here: same object, more elaboration, richer border.

`shape` is not override-able at any layer. If a future badge genuinely needs to break
its category's silhouette, it wants to be its own category. If that turns out to be
wrong, loosen `PROTECTED_OVERRIDE_KEYS` deliberately, and write down why.

Changing a *category's* own `icon` or `shape` is legal — that is a deliberate redesign,
not a level quietly diverging. `update <category> --icon ...` allows it;
`update <category> <level> --icon ...` does not.

## Editing

```sh
badges.py create devotion --shape circular --icon "a lit oil lamp" --color "warm amber" \
    --level "1=Kindled" --level "2=Steady|with a taller flame" \
    --level "3=Constant|with a halo of fine rays"

badges.py create night_vigil --shape circular --icon "a crescent moon over still water" \
    --color "deep slate" --border "plain double ring"

badges.py update devotion --color "burnt orange"
badges.py update devotion 3 --icon-variation "with a doubled halo"
badges.py update devotion 3 --color "blood red"      # writes a level override
badges.py delete devotion                            # confirms first
```

`--level` is `N=Label` with an optional `|icon_variation` after the label. Every mutation
re-validates before writing and replaces the file atomically, so a rejected edit leaves
`badges.json` untouched. After a category-wide change the tool prints every affected
prompt, so you can read the family side by side.

Editing `badges.json` by hand is fine too — run `badges.py validate` afterwards.

## Things that will bite you

**Write the icon as a silhouette, not a scene.** These render at roughly 40–60px in the
app. "An open hand releasing a single small bird" survives; anything with a background,
a second subject, or fine interior texture turns to mush. The `detail_level` global says
this to the model, but the model will still follow a busy `icon` string over it.

**`icon_variation` is appended with a comma, so write it as a continuation.** "with a
single ring of fine radiating lines around it" — not a full sentence, no leading capital.

**Level 3 borders are already ornate; don't also make level 3 the busiest icon.** If both
escalate at once the badge stops being legible exactly where you most wanted it to feel
earned. Escalate the border by default and the icon sparingly.

**Colors are prose, not hex, and that is deliberate.** Image models handle "soft teal"
better than `#4A9B8E`, and the generated art gets colour-corrected against the app
palette afterwards anyway. Keep the prose in the same family as `design-theme.html` so
correction is a nudge and not a repaint.

**`delete` is a hard delete.** It removes the category from `badges.json` outright, and
any achievement a user has already earned loses the definition that names and renders it.
The tool asks for the category name to confirm. If the badge has shipped, prefer leaving
it in place.

**`--yes` is not a way past the confirmation.** The prompt exists to catch a human
mid-mistake, so it only works at a terminal; anywhere else — a script, or Claude running
the command — `delete` refuses and names `--yes` in the error. That error is not
permission to use the flag. Pass `--yes` only when a specific category has been named for
deletion by the person who wants it gone, never to get an automated run unstuck.
