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
stroke with metallic gold piping along both edges and a hollow centre. Colour is full at the
leftmost point and thins all the way across, gaining pace as it goes and reaching zero at the
rightmost point — learned things fade, and you come back to them.

The fade is deliberately uneven. `FADE_STOPS` is the underlying ramp — solid at the left,
shedding slowly at first and steeply past the middle — but that ramp is never used straight.
A filter warps it before it becomes a mask, so no two arms of the star fade at the same rate
or end in the same place.

Geometry is the nonagram `{9/3}` — nine points at 40°, inner radius ratio 0.6527. That is the
three-overlapping-triangles construction, the canonical Bahá'í form. Do not eyeball the inner
radius; the ratio is `cos(60°)/cos(40°)`.

## How the fade is warped

Two layers of `feTurbulence`, both applied to the ramp inside the `organic` filter:

- **Drift** displaces the ramp horizontally, so the fade front wanders instead of running down
  a straight vertical line. `DRIFT_FREQ` is anisotropic on purpose — coarser across than down,
  so variation reads arm-to-arm rather than as ripple. The drift map is itself pulled back to
  neutral 0.5 by the ramp (`driftHeld`), because a displacement that stays live at the left
  drags faded pixels inward and eats the solid arm the design depends on.
- **Mottle** pushes the ramp *both* ways: `holding` patches keep more colour than the ramp
  alone, `thinning` patches lose more. It is windowed by the ramp itself (`past` is `1 - ramp`,
  softened by `MOTTLE_ONSET`), so the patches are absent at the left and strongest at the right.
  That window is what keeps the left edge solid without a second gradient.

A mottle that only subtracts does not read as mottling. Multiplying a ramp that is already
heading to zero just makes a faint area fainter — the eye sees a smooth fade with a wavy edge.
The patches that hold *more* than the ramp are what make it look like worn enamel, so
`MOTTLE_LIFT` matters at least as much as `MOTTLE_DEPTH`.

`fractalNoise` clusters tightly around 0.5, so raw turbulence moves almost nothing. Both layers
are stretched by a `feComponentTransfer` first — `DRIFT_CONTRAST` and `MOTTLE_CONTRAST` are
what give the noise a usable range, and turning `DRIFT` alone mostly does nothing.

Feature size is the thing to get right, and it is judged at 40px, not at 1024. Too fine and
every blotch averages back into a flat wash on the home screen; too coarse and the star loses
whole arms and stops reading as a nine-pointed star at all. The frequencies here sit between
those two failures — keep octaves low, since the extra ones only contribute grain that the
downscale eats.

## Things that will bite you

**Do not combine mask layers with `feComposite operator="arithmetic"`.** It runs on alpha too,
so `k1="-1" k2="1"` over two opaque layers yields alpha `1·(1-1) = 0`, the mask goes black, and
the star disappears from all three icons with no error anywhere. Multiply with
`feBlend mode="multiply"`, which leaves alpha alone.

**The mask rect is bled `BLEED` px past the plate.** The displacement pulls pixels in from
outside the star, and if it samples past the rect it pulls in transparency — which reads as
*hidden*, punching holes in the solid left side.

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
