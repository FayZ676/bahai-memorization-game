# Store preview tiles

Source of truth for the App Store preview images. The PNGs in
`store-screenshots/iphone-6.9-framed/` and `ipad-13-framed/` are generated artefacts —
edit this script, never the output.

```sh
python3 Design/StoreFrames/generate_store_frames.py --device both
python3 Design/StoreFrames/generate_store_frames.py --only 2-hide-words   # one tile
```

Needs headless Chrome to rasterise (`CHROME=/path/to/chrome` to override the search).
`--html-only` writes the intermediate HTML and prints its path, which is the fastest way
to iterate on layout in a browser.

## What it makes

Five tiles that read in order as one pass through the app — pick a prayer, hide a word,
hide more, say it aloud, know it. Tiles 2 and 3 are the same chunk of the same passage at
two stages, so the set demonstrates the loop instead of describing it. Reordering the list
breaks that; the story is the point, not the coverage. The recitation beat sits after that
pair rather than between them, for the same reason.

`4-recite.png` has no raw capture yet — the recitation screen cannot be shot in a simulator
(`store-screenshots/README.md`). Its tile is skipped until one exists, so the set generates
as four and uploads as four; nothing else has to change when the capture lands.

The closing tile is dark. It is the one place a theme can be shown without spending a tile
on it, and it lands on the library, where the ramps and the streak carry the same reading
in either appearance. A tile can override its source or theme per device through
`per_device`, keyed by the raw folder name — the iPad was never shot in dark, so its
`4-know.png` falls back to the light library rather than dropping the beat.

Each tile names its own output file, so `TILES` order is the upload order and the raw
capture it draws from can keep whatever name it was shot under. Input is
`store-screenshots/<device>/`; a tile whose source is missing is skipped, which is why
`--device ipad` produces three tiles — the iPad was never shot for the later session stage,
and its three land as 1, 2 and 4, which is still the same story with a beat missing.

The headline is centred in the band above the phone rather than hung from a fixed top, so
one-line and two-line headlines both sit right without a per-tile nudge. Line breaks are
explicit `\n` in the headline string — the measure is never the thing that decides them.

Every output is asserted to be exactly the size App Store Connect demands — 1320×2868 for
iPhone, 2064×2752 for iPad. Regenerate after any reshoot; the tiles embed the screenshot,
so a stale tile will keep showing the old UI.

## Things that will bite you

**The geometry is proportional, not absolute.** `GEOMETRY` holds fractions of the canvas,
measured off the reference tile, so the same numbers compose both devices. Change a
fraction and both sizes move together. `IPAD` overrides only the fractions that must
differ — its canvas is far squarer, so headline and phone both have to shrink.

**The headline carries the whole message — there is no subhead.** Only the first two or
three tiles appear in search results, at roughly 150px wide, where body copy is an
illegible grey band. Keep the headline to five words or fewer and let it say what the
screen does.

**Every claim in the copy has to hold against the build, not against the last listing.**
The counts are hardcoded here, so re-derive them from `library.json` whenever it is rebuilt —
225 prayers, 153 Hidden Words, 249 Ruhi passages at the time of writing — and check that
feature claims match the app (reminders exist, so "no notifications" is false; the
achievement tile names a count that `AchievementCatalog.all` has to still agree with).

**The phone bleeds off the bottom on purpose.** Fitting the whole device on the canvas
would shrink the UI to the point where nothing in it can be read. The screenshot is scaled
to the bezel's inner width and whatever runs past the bottom edge is cropped.

**A black bezel disappears on the dark ground.** Dark tiles draw the phone's silhouette
with an inset rim highlight instead. Without it the screenshot appears to float in a void.

**The ground is the app's own paper token**, so the phone's screen and the canvas are the
same colour and the bezel reads as the only edge. Do not swap in a marketing gradient —
that is what makes these look like a template rather than like Verses.
