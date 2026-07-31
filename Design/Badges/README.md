# Achievement badges

Source of truth for the prompts that generate achievement badge art. The prompt is a
generated artefact — edit the registries in `generate_badge_prompt.py`, never a
prompt you pasted somewhere earlier.

```sh
python3 Design/Badges/generate_badge_prompt.py healing 1
python3 Design/Badges/generate_badge_prompt.py first_prayer_memorized
python3 Design/Badges/generate_badge_prompt.py --list
python3 Design/Badges/generate_badge_prompt.py --all
```

The point is determinism. A badge set only reads as a *set* if every badge came out of
the same style anchor, so the anchor lives in one string and the per-badge differences
are a handful of substituted fields. If you find yourself hand-editing a prompt before
pasting it into an image model, that difference belongs in the registry instead.

## Layering

Broadest to narrowest, later layers win:

| Layer | Owns | Applies to |
|---|---|---|
| `GLOBAL` | `finish`, `detail_level` | every badge, always |
| `LEVEL_REGISTRY` | default `border` per level | any leveled category |
| `CATEGORY_REGISTRY[c]` | `shape`, `icon`, `color` | one category |
| `CATEGORY_REGISTRY[c]["levels"][n]` | `label`, `icon_variation`, `overrides` | one badge |

A category with no `levels` key is binary — earned or not — and supplies its own
`border` directly. Passing a level to it is an error, as is omitting a level for a
leveled category. The generator raises rather than guessing.

## Two protected fields

`icon` and `shape` may **never** appear in a level's `overrides`; validation rejects it
by name. This is the rule that keeps a badge family recognisable as it levels up.

`icon` can still change with level, but only *additively*, via `icon_variation` — the
string is appended to the category icon, never substituted for it. So the compass rose
at level 3 is still a compass rose, with rings of radiating lines around it. That is the
whole visual grammar of progression here: same object, more elaboration, richer border.

`shape` is not override-able at any layer. If a future badge genuinely needs to break
its category's silhouette, it wants to be its own category. If that turns out to be
wrong, loosen `PROTECTED_OVERRIDE_KEYS` deliberately, and write down why.

## Adding a category

Add one entry to `CATEGORY_REGISTRY`:

```python
"category_name": {
    "shape": "circular",
    "icon": "a bold, describable object silhouette",
    "color": "soft teal",
    "levels": {
        1: {"label": "Novice"},
        2: {"label": "Practiced", "icon_variation": "with ..."},
        3: {"label": "Healer", "icon_variation": "with ..."},
    },
},
```

Then run `--all` and read the three prompts side by side before generating any art.

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
