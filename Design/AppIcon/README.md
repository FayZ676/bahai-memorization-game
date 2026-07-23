# App icon

Source of truth for the Verses app icon. The PNGs in `Assets.xcassets/AppIcon.appiconset`
are generated artefacts — edit this script, never the PNGs.

```sh
python3 Design/AppIcon/generate_app_icon.py
```

Writes `AppIcon.png`, `AppIcon-Dark.png` and `AppIcon-Tinted.png` straight into the iconset,
then asserts each is 1024×1024 with the correct alpha. Needs headless Chrome to rasterise
(`CHROME=/path/to/chrome` to override the search). `--svg-only` dumps the SVGs here instead.

## The mark

A nine-pointed star, drawn as a **band** rather than a filled shape: a thick green enamel
stroke with metallic gold piping along both edges and a hollow centre. Colour is held at full
strength through the exact horizontal centre, then fades out, reaching zero just before the
rightmost point — learned things fade, and you come back to them.

Geometry is the nonagram `{9/3}` — nine points at 40°, inner radius ratio 0.6527. That is the
three-overlapping-triangles construction, the canonical Bahá'í form. Do not eyeball the inner
radius; the ratio is `cos(60°)/cos(40°)`.

## Things that will bite you

**The gold only reads as metal because the foil gradient repeats.** It is a
`spreadMethod="reflect"` gradient with a ~150px period, so bright and dark bands cycle several
times around the star. A single gradient stretched across the whole shape puts each 12px length
of piping on one flat tone, and it goes back to looking like dull bronze.

**The ground is warm cream, and that contradicts the design system on purpose.**
`design-theme.html` specifies paper as `#ECEEE8`, explicitly "cool luminous paper (not warm
cream)". The icon is a deliberate exception. Don't reconcile it, and don't let the warm cream
leak into app UI.

**The three variants have different alpha rules.** Light must be opaque — the App Store rejects
an alpha channel on it. Dark and tinted must be transparent, because iOS composites them over
its own substrate; shipping an opaque tile there is what makes an icon look wrong next to
system icons on a dark home screen. The script enforces all three.

**The dark variant uses a more saturated green** (`#22A972`) than the app's dark-mode accent.
The accent is tuned for text legibility and looks muddy at icon scale.

The band is a stroke, not an outline path, so `BAND` and `PIPE` change the weight without
touching the geometry. Mitred joins with a high miter limit keep the points sharp — the tip
angle is 60°, so the miter never runs away.
