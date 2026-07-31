---
name: badge-prompt
description: Generate the image-generation prompt for an achievement badge icon, or list, create, update or delete a badge category or level. Use whenever the user asks for a badge prompt, a new achievement badge, a new badge tier, or wants an existing badge changed, removed, or its art regenerated. Triggers on "badge", "achievement icon", "badge prompt", "new achievement", "badge tier", "badge list".
---

# Achievement badges

Badge style lives in `Design/Badges/badges.json`; `Design/Badges/badges.py` is the only
thing that reads or writes it. The design rationale is in `Design/Badges/README.md` —
read it before any edit.

Never compose a badge prompt yourself, never paste a previously generated prompt from
the conversation, and never tweak a generated prompt before handing it over. Never
hand-edit `badges.json` when a verb exists for the change. Same input, same bytes out —
that is the entire reason this exists. A badge set only reads as a set if every prompt
came out of the same style anchor.

Always run the tool and quote its actual output. If it errors, surface the message as-is
— the errors are written to say exactly what is wrong — and fix the cause rather than
working around it by hand.

## Verbs

```sh
python3 Design/Badges/badges.py list
python3 Design/Badges/badges.py prompt <category> [level]
python3 Design/Badges/badges.py prompt --all
python3 Design/Badges/badges.py validate

python3 Design/Badges/badges.py create <category> --shape S --icon I --color C \
    --level "1=Label" --level "2=Label|icon variation"
python3 Design/Badges/badges.py create <category> --shape S --icon I --color C --border B
python3 Design/Badges/badges.py update <category> [level] [--shape|--icon|--color|--border|--label|--icon-variation]
python3 Design/Badges/badges.py delete <category>
```

Run `list` first when you are not certain a category exists. Output prompts verbatim in
a fenced block so the user can paste them straight into an image model.

`create` with `--level` makes a leveled category; with `--border` a binary one. A leveled
category takes its border from the level registry, so the two are mutually exclusive.

## The rules the tool enforces

- **`icon` and `shape` are protected at the level layer.** A level elaborates its icon
  only additively, through `--icon-variation`, appended to the category icon and never
  replacing it. Changing a *category's* own icon or shape is legal — that is a deliberate
  redesign — so `update <category> --icon` works while `update <category> <level> --icon`
  is refused.
- **Put a change at the broadest layer that is still true.** True of every badge → the
  `global` block. True of every level 2 → the `levels` registry. Not per category.
- **A category with no levels is binary** and supplies its own `border`.

Validation runs on read and again before every write, so a rejected edit leaves
`badges.json` untouched. After changing anything, run `prompt --all` (or read the prompts
the mutation prints) and check the family still reads as one set.

## Deleting

`delete` is a hard delete: the category leaves `badges.json`, and any achievement a user
has already earned loses the definition that names and renders it.

The tool asks for the category name to confirm. Because you are not an interactive
terminal it will refuse and tell you to pass `--yes`. **Only pass `--yes` when the user
has explicitly asked for that specific category to be deleted** — never to get past the
prompt on your own initiative. If the badge may have shipped, say so and suggest leaving
it in place instead.

## Where the art goes

Generated badge PNGs belong in `MemorizationGame/Assets.xcassets`, matching the app icon
convention: the asset is the artefact, the config is the source of truth. Follow the
token system in `Theme/` for surrounding UI, and colour-correct generated art toward the
`design-theme.html` palette rather than restyling it in the prompt.
