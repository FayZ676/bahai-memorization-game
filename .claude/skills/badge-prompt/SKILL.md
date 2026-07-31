---
name: badge-prompt
description: Generate the image-generation prompt for an achievement badge icon, or add/change a badge category or level. Use whenever the user asks for a badge prompt, a new achievement badge, a new badge tier or level, or wants an existing badge's art regenerated or restyled. Triggers on "badge", "achievement icon", "badge prompt", "new achievement", "badge tier".
---

# Achievement badge prompts

Badge prompts are **generated, never hand-written**. The generator and its style
registries live at `Design/Badges/generate_badge_prompt.py`; the design rationale and
the rules behind it are in `Design/Badges/README.md`.

Never compose a badge prompt yourself, never paste a previously generated prompt from
the conversation, and never tweak a generated prompt before handing it over. Same input,
same bytes out — that is the entire reason this exists. A badge set only reads as a set
if every prompt came out of the same style anchor.

## Getting a prompt

```sh
python3 Design/Badges/generate_badge_prompt.py <category> [level]
python3 Design/Badges/generate_badge_prompt.py --list   # every registered badge
python3 Design/Badges/generate_badge_prompt.py --all    # every prompt, labelled
```

Run `--list` first if you are not certain the category exists. If the script raises,
surface the error as-is; the messages are written to say exactly what is wrong (missing
level, level on a non-leveled category, unknown category). Do not work around an error
by generating the prompt by hand.

Output the prompt verbatim in your reply, in a fenced block, so the user can copy it
straight into an image model.

## Adding or changing a badge

Edit the registries in `generate_badge_prompt.py` — that is the only correct place for a
style decision. Read `Design/Badges/README.md` before editing; it covers the layering
order, what each layer owns, and the icon/silhouette pitfalls.

The rules that matter most:

- **`icon` and `shape` are protected.** They may never appear in a level's `overrides`;
  validation rejects it by name. A level changes its icon only *additively*, through
  `icon_variation`, which is appended to the category icon and never replaces it.
- **Put a change at the broadest layer that is still true.** Something true of every
  badge belongs in `GLOBAL`, not repeated per category. Something true of every level 2
  belongs in `LEVEL_REGISTRY`, not per category.
- **A category with no `levels` key is binary** — earned or not — and supplies its own
  `border`.

After editing, run `--all` and check that the family still reads as one set, then show
the user the affected prompts.

## Where the art goes

Generated badge PNGs belong in `MemorizationGame/Assets.xcassets`, matching the app icon
convention: the asset is the artefact, the script is the source of truth. Follow the
existing token system in `Theme/` for any surrounding UI, and colour-correct generated
art toward the `design-theme.html` palette rather than restyling it in the prompt.
