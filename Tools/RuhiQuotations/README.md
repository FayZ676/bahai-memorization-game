# Ruhi quotations

`ruhi.json` holds every passage the Ruhi Institute courses ask you to memorize, Books 1
through 8. It is generated, not hand-edited; `build_ruhi.py` is the source of truth for it,
and this README is the source of truth for the script.

```
python3 Tools/RuhiQuotations/build_ruhi.py            # rebuild from the cached text
python3 Tools/RuhiQuotations/build_ruhi.py --refresh  # re-download the books first
python3 Tools/RuhiQuotations/build_ruhi.py --dry-run  # print the tree, write nothing
```

`ruhi.json` is not shipped. `Tools/LibrarySnapshot/build_library.py` folds it into
`MemorizationGame/Resources/library.json`, which is the file the app bundles — so after
rebuilding here, rebuild the library snapshot too.

## Where the text comes from

Books 2 through 8 come from the single-file PDF editions published by the Ruhi Institute at
`ruhi.org/full_texts`; the exact URLs live in `BOOKS` in the script. `pdftotext -layout`
turns each one into the cached text under `cache/`, which is committed so a rebuild works
without network access. The PDFs themselves are not committed — they are 20 MB and
`--refresh` fetches them again.

Book 1 has no machine-readable source. Its 24 quotations were entered by hand, and the
script carries them through from `ruhi.json` untouched; it refuses to run if they are
missing.

The junior youth texts — *Breezes of Confirmation*, *Walking the Straight Path* and the rest
— are deliberately absent. The Ruhi Institute publishes full texts for the main sequence
only, so there is nothing to extract and no footnotes to attribute against. The handful of
junior youth passages that Book 5 reproduces in its sample lessons are already here, under
Book 5. Do not fill the gap from memory.

Justified text in these PDFs breaks words across lines, so `remem- ber` and `All- Bountiful`
arrive looking alike. `SPLIT_ACROSS_LINES` and `TRULY_HYPHENATED` say which is which, and
the script stops on any pair it has not been told about rather than guessing.

## Which passages are taken

A passage is included when the book asks the reader to commit it to memory — "you may wish
to memorize the following", "it is suggested that you memorize one or two of these",
"Memorize the above quotation", the `Memorization` heading in a junior youth lesson, and so
on. The instruction sets the span:

- Instructions that point backwards ("the quotations in this section", "each of the sets
  above") take the quotations between the previous section heading and the instruction.
- Instructions that point forwards take the quotations that follow, stopping at the next
  section or lesson heading, or at the first gap of more than fourteen lines — which is what
  separates a block of quotations from the prose that follows it.
- A singular cue ("the above passage", "memorize the prayer below") takes exactly one.

Deliberately dropped: dialogue from the stories in Book 3, which is narration rather than
scripture; and the tutor-training discussions in Books 6 and 7, where memorization is the
topic of conversation rather than an instruction to the reader. A passage that appears twice
in the same book is kept once.

## Attribution

Each quotation carries a footnote number that resolves against the `REFERENCES` block at
the end of its unit. `Ibid.` chains inherit both the work and the author of the citation
above them. The author is then read from the citation — from an explicit name where the
reference gives one, otherwise from the work itself, since only one of Bahá'u'lláh, the Báb
and 'Abdu'l-Bahá revealed any given work. Where a book quotes without a footnote, the
attribution is pinned by hand in `UNATTRIBUTED`. The script fails loudly rather than
shipping a passage it cannot attribute or place.

The last tag on each entry is the short work title, so "The Hidden Words, Arabic no. 1"
rather than the full publication citation.

## Shape

The app browses `collection → section → category → entry`, which here is
`Ruhi → Book 3 → Unit 2: Lessons for Children's Classes, Grade 1 → the passage`. All seven
books sit under the one `Ruhi` collection, named by number alone — the unit beneath says
what the book is about. The full titles stay in `BOOKS` in the script, unused by the app. The
section or lesson the passage was drawn from is kept as a tag rather than a level, because
the hierarchy has no room for a fourth.

## Ids

Ids are minted by `build_library.py`, not here. Ruhi entries seed the hash with the book as
well as the collection and the text, because several passages are memorized in more than one
book and would otherwise collide.

Text is normalized to NFC. The PDFs decompose their accents, and everything else in the
library is composed.
