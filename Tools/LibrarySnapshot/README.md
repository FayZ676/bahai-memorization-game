# Library snapshot

`MemorizationGame/Resources/library.json` is generated, not hand-edited. `build_library.py`
is the source of truth for it; this README is the source of truth for the script.

```
python3 Tools/LibrarySnapshot/build_library.py            # rebuild from the cached HTML
python3 Tools/LibrarySnapshot/build_library.py --refresh  # re-download from bahai.org first
python3 Tools/LibrarySnapshot/build_library.py --dry-run  # print the tree, write nothing
```

The downloaded XHTML editions are cached next to the script and committed, so a rebuild is
reproducible without network access. `--refresh` replaces them.

## Where the text comes from

Everything authoritative comes from the Bahá'í Reference Library on bahai.org, taken from
the single-file XHTML edition of each book rather than the paginated web view:

- **Prayers** — *Bahá'í Prayers: A Selection of Prayers Revealed by Bahá'u'lláh, the Báb,
  and 'Abdu'l-Bahá*
- **The Hidden Words** — *The Hidden Words of Bahá'u'lláh*

The `Ruhi` collection is not from bahai.org. It is read from
`Tools/RuhiQuotations/ruhi.json`, which has its own generator and its own README; rebuild
that first if the Ruhi books have changed. Any other collection already in `library.json` is
carried through unchanged, so it survives a rebuild untouched.

## How the structure is derived

The app browses `collection → section → category (primaryTag) → entry`, which is one level
shallower than the prayer book's table of contents. The mapping:

- **section** — the book's top-level part (Obligatory Prayers, General Prayers, Occasional
  Prayers, Special Tablets).
- **category** — the book's *first* heading below that (Healing, The Departed, Teaching …).
  Deeper headings are flattened into it. Using the deepest heading instead would merge
  unrelated groups, because the book reuses names — "For Women" appears under both Healing
  and The Departed.
- **tags** — the full heading chain, so the flattened detail stays searchable.
- **heading** — set only when a heading names exactly one prayer, in which case that prayer
  is titled after it ("The Long Healing Prayer", "Tablet of Aḥmad"). Otherwise it is empty
  and the app falls back to the prayer's first line. A rubric such as "To be recited once in
  twenty-four hours" is appended to a heading when one exists.

The prayer book's table of contents is the only structural signal used. Headings are located
by their anchor ids rather than by CSS class, because the book styles category headings and
prayer titles identically.

Hidden Words keep their number and invocation as the heading ("7. O Son of Man!"), and are
grouped by part — From the Arabic (71), From the Persian (82). Grouping them by invocation
instead was tried and rejected: it produces about a hundred categories holding one entry each.

## What is deliberately dropped

- Editorial matter that is quoted rather than revealed: any block whose whole text is wrapped
  in typographic quotes, and any block attributed to someone other than Bahá'u'lláh, the Báb,
  or 'Abdu'l-Bahá (Shoghi Effendi letters, Synopsis and Codification extracts).
- Wholly parenthetical notes, e.g. "(Naw-Rúz, March 21, is the first day of the Bahá'í year.)".
- Footnote markers and their reference links.
- The Hidden Words preamble and closing passage, which are unnumbered.

The two prayers on the book's opening pages ("Blessed is the spot…" and "Intone, O My
servant…") sit outside the table of contents entirely. They are kept, under a section named
`Opening Words` — the one section name here that the book does not itself supply.

## Ids

`id` is the first four bytes of `sha1(collection + "\n" + text)`, so an entry keeps its id
across rebuilds and ids do not shift when entries are added or reordered. Ruhi entries put
the section in the seed as well, because the same passage is memorized in more than one book
and the two would otherwise hash alike. This matters
because ids are referenced from outside this file: `Model/Achievement.swift` hardcodes them,
and saved passages persist them as `sourceID`. The script fails loudly on a collision.

Changing an entry's text changes its id. If a rebuild alters the text of an achievement
prayer, update `Achievement.swift` to match.
