#!/usr/bin/env python3
"""Regenerate the Verses app icon (light, dark and tinted) into Assets.xcassets.

Usage:  python3 Design/AppIcon/generate_app_icon.py [--svg-only]

Requires headless Chrome for rasterisation; set CHROME to override the path.
See README.md for the design rationale behind the constants below.
"""

import argparse
import math
import os
import pathlib
import shutil
import struct
import subprocess
import sys
import tempfile

PLATE = 1024
CX, CY = 512, 508
RADIUS = 336.0
RATIO = math.cos(math.radians(60)) / math.cos(math.radians(40))
POINTS = 9
BAND = 58.0
PIPE = 12.0
STROKE_HALF = BAND / 2 + PIPE

PAPER_A, PAPER_B = "#F6F2E7", "#EFE9DA"
GREEN_LIGHT = "#26654A"
GREEN_DARK = "#22A972"
GREY_ENAMEL = "#9A9A9A"

FOIL = [
    (0.00, "#7A5514"), (0.18, "#B58A28"), (0.34, "#E9CD74"),
    (0.50, "#FDF6DA"), (0.66, "#E4C165"), (0.82, "#B0821F"), (1.00, "#7A5514"),
]
FOIL_GREY = [
    (0.00, "#6E6E6E"), (0.18, "#8E8E8E"), (0.34, "#D2D2D2"),
    (0.50, "#FFFFFF"), (0.66, "#CFCFCF"), (0.82, "#8A8A8A"), (1.00, "#6E6E6E"),
]
FOIL_PERIOD = 150.0
FOIL_DIR = (1.0, 0.85)

FADE_STOPS = [
    (0.00, 1.00), (0.22, 0.95), (0.42, 0.82),
    (0.60, 0.60), (0.76, 0.34), (0.90, 0.12), (1.00, 0.00),
]

DRIFT = 430.0
DRIFT_FREQ = (0.0013, 0.0029)
DRIFT_OCTAVES = 2
DRIFT_SEED = 11
DRIFT_CONTRAST = 3.4
MOTTLE_FREQ = (0.0020, 0.0036)
MOTTLE_OCTAVES = 2
MOTTLE_SEED = 29
MOTTLE_DEPTH = 3.6
BLEED = 420

GREY_MATRIX = ("0.34 0.33 0.33 0 0  0.34 0.33 0.33 0 0  "
               "0.34 0.33 0.33 0 0  0 0 0 0 1")

_COS = [math.cos(math.radians(-90 + (360 / POINTS) * k)) for k in range(POINTS)]
XMIN = CX + min(_COS) * RADIUS - STROKE_HALF
SPAN = (CX + max(_COS) * RADIUS + STROKE_HALF) - XMIN

REPO = pathlib.Path(__file__).resolve().parents[2]
ICONSET = REPO / "MemorizationGame/Assets.xcassets/AppIcon.appiconset"

CHROME_CANDIDATES = [
    os.environ.get("CHROME", ""),
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    shutil.which("chromium") or "",
    shutil.which("google-chrome") or "",
]


def star_points(radius=RADIUS, ratio=RATIO, rotation=-90.0, n=POINTS):
    step = 360.0 / n
    pts = []
    for k in range(n):
        outer = math.radians(rotation + k * step)
        pts.append((CX + radius * math.cos(outer), CY + radius * math.sin(outer)))
        inner = math.radians(rotation + step / 2 + k * step)
        pts.append((CX + radius * ratio * math.cos(inner), CY + radius * ratio * math.sin(inner)))
    return " ".join("%.2f,%.2f" % p for p in pts)


def render_svg(uid, green, foil, ground, shadow):
    pts = star_points()
    foil_stops = "".join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in foil)

    dx, dy = FOIL_DIR
    length = math.hypot(dx, dy)
    dx, dy = dx / length * FOIL_PERIOD, dy / length * FOIL_PERIOD

    fade_stops = "".join(
        '<stop offset="%.3f" stop-color="#%02X%02X%02X"/>' % ((o,) + (round(v * 255),) * 3)
        for o, v in FADE_STOPS
    )

    if ground is None:
        ground_def = ground_use = ""
    else:
        ground_def = (f'<linearGradient id="bg{uid}" x1="0" y1="0" x2="0.35" y2="1">'
                      f'<stop offset="0" stop-color="{ground[0]}"/>'
                      f'<stop offset="1" stop-color="{ground[1]}"/></linearGradient>')
        ground_use = f'<rect width="{PLATE}" height="{PLATE}" fill="url(#bg{uid})"/>'

    if shadow > 0:
        shadow_def = (f'<filter id="lift{uid}" x="-20%" y="-20%" width="140%" height="140%">'
                      f'<feDropShadow dx="0" dy="5" stdDeviation="8" flood-color="#2A2A22" '
                      f'flood-opacity="{shadow}"/></filter>')
        shadow_use = f' filter="url(#lift{uid})"'
    else:
        shadow_def = shadow_use = ""

    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {PLATE} {PLATE}" width="{PLATE}" height="{PLATE}">
<defs>
  {ground_def}
  <linearGradient id="foil{uid}" gradientUnits="userSpaceOnUse" spreadMethod="reflect"
    x1="{XMIN:.1f}" y1="0" x2="{XMIN + dx:.1f}" y2="{dy:.1f}">{foil_stops}</linearGradient>
  <linearGradient id="fadeG{uid}" gradientUnits="userSpaceOnUse"
    x1="{XMIN:.1f}" y1="0" x2="{XMIN + SPAN:.1f}" y2="0">{fade_stops}</linearGradient>
  <filter id="organic{uid}" x="-10%" y="-10%" width="120%" height="120%" color-interpolation-filters="sRGB">
    <feTurbulence type="fractalNoise" baseFrequency="{DRIFT_FREQ[0]} {DRIFT_FREQ[1]}"
      numOctaves="{DRIFT_OCTAVES}" seed="{DRIFT_SEED}" result="drift"/>
    <feColorMatrix in="drift" type="matrix" values="{GREY_MATRIX}" result="driftGrey"/>
    <feComponentTransfer in="driftGrey" result="driftWide">
      <feFuncR type="linear" slope="{DRIFT_CONTRAST}" intercept="{0.5 - DRIFT_CONTRAST / 2}"/>
      <feFuncG type="linear" slope="{DRIFT_CONTRAST}" intercept="{0.5 - DRIFT_CONTRAST / 2}"/>
      <feFuncB type="linear" slope="{DRIFT_CONTRAST}" intercept="{0.5 - DRIFT_CONTRAST / 2}"/>
    </feComponentTransfer>
    <feComponentTransfer in="SourceGraphic" result="right">
      <feFuncR type="linear" slope="-1" intercept="1"/>
      <feFuncG type="linear" slope="-1" intercept="1"/>
      <feFuncB type="linear" slope="-1" intercept="1"/>
    </feComponentTransfer>
    <feComponentTransfer in="SourceGraphic" result="halfLeft">
      <feFuncR type="linear" slope="0.5"/>
      <feFuncG type="linear" slope="0.5"/>
      <feFuncB type="linear" slope="0.5"/>
    </feComponentTransfer>
    <feBlend in="driftWide" in2="right" mode="multiply" result="driftRight"/>
    <feComposite in="driftRight" in2="halfLeft" operator="arithmetic"
      k1="0" k2="1" k3="1" k4="0" result="driftHeld"/>
    <feDisplacementMap in="SourceGraphic" in2="driftHeld" scale="{DRIFT}"
      xChannelSelector="R" yChannelSelector="G" result="wander"/>
    <feTurbulence type="fractalNoise" baseFrequency="{MOTTLE_FREQ[0]} {MOTTLE_FREQ[1]}"
      numOctaves="{MOTTLE_OCTAVES}" seed="{MOTTLE_SEED}" result="grain"/>
    <feColorMatrix in="grain" type="matrix" values="{GREY_MATRIX}" result="grainGrey"/>
    <feComponentTransfer in="grainGrey" result="thinning">
      <feFuncR type="linear" slope="-{MOTTLE_DEPTH}" intercept="{MOTTLE_DEPTH / 2}"/>
      <feFuncG type="linear" slope="-{MOTTLE_DEPTH}" intercept="{MOTTLE_DEPTH / 2}"/>
      <feFuncB type="linear" slope="-{MOTTLE_DEPTH}" intercept="{MOTTLE_DEPTH / 2}"/>
    </feComponentTransfer>
    <feComponentTransfer in="wander" result="opened">
      <feFuncR type="linear" slope="-1" intercept="1"/>
      <feFuncG type="linear" slope="-1" intercept="1"/>
      <feFuncB type="linear" slope="-1" intercept="1"/>
    </feComponentTransfer>
    <feBlend in="opened" in2="thinning" mode="multiply" result="bite"/>
    <feComponentTransfer in="bite" result="keep">
      <feFuncR type="linear" slope="-1" intercept="1"/>
      <feFuncG type="linear" slope="-1" intercept="1"/>
      <feFuncB type="linear" slope="-1" intercept="1"/>
    </feComponentTransfer>
    <feBlend in="wander" in2="keep" mode="multiply"/>
  </filter>
  <mask id="fade{uid}" maskUnits="userSpaceOnUse" x="0" y="0" width="{PLATE}" height="{PLATE}">
    <rect x="-{BLEED}" y="-{BLEED}" width="{PLATE + 2 * BLEED}" height="{PLATE + 2 * BLEED}"
      fill="url(#fadeG{uid})" filter="url(#organic{uid})"/>
  </mask>
  {shadow_def}
</defs>
{ground_use}
<g mask="url(#fade{uid})">
  <g{shadow_use}>
    <polygon points="{pts}" fill="none" stroke="url(#foil{uid})"
      stroke-width="{BAND + 2 * PIPE}" stroke-linejoin="miter" stroke-miterlimit="12"/>
    <polygon points="{pts}" fill="none" stroke="{green}"
      stroke-width="{BAND}" stroke-linejoin="miter" stroke-miterlimit="12"/>
  </g>
</g>
</svg>'''


VARIANTS = {
    "AppIcon": dict(uid="lt", green=GREEN_LIGHT, foil=FOIL,
                    ground=(PAPER_A, PAPER_B), shadow=0.07, opaque=True),
    "AppIcon-Dark": dict(uid="dk", green=GREEN_DARK, foil=FOIL,
                         ground=None, shadow=0.0, opaque=False),
    "AppIcon-Tinted": dict(uid="tn", green=GREY_ENAMEL, foil=FOIL_GREY,
                           ground=None, shadow=0.0, opaque=False),
}


def find_chrome():
    for candidate in CHROME_CANDIDATES:
        if candidate and pathlib.Path(candidate).exists():
            return candidate
    sys.exit("Could not find Chrome. Set CHROME=/path/to/chrome and retry.")


def rasterise(chrome, svg_path, png_path, transparent):
    args = [
        chrome, "--headless", "--disable-gpu", "--force-device-scale-factor=1",
        f"--screenshot={png_path}", f"--window-size={PLATE},{PLATE}", str(svg_path),
    ]
    if transparent:
        args.insert(4, "--default-background-color=00000000")
    subprocess.run(args, check=True, capture_output=True)


def png_info(path):
    with open(path, "rb") as handle:
        header = handle.read(33)
    if header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path} is not a PNG")
    width, height = struct.unpack(">II", header[16:24])
    return width, height, header[25] in (4, 6)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--svg-only", action="store_true")
    args = parser.parse_args()

    ICONSET.mkdir(parents=True, exist_ok=True)
    work = pathlib.Path(tempfile.mkdtemp(prefix="verses-icon-"))
    chrome = None if args.svg_only else find_chrome()

    for name, spec in VARIANTS.items():
        opaque = spec.pop("opaque")
        svg_path = work / f"{name}.svg"
        svg_path.write_text(render_svg(**spec))
        spec["opaque"] = opaque

        if args.svg_only:
            shutil.copy(svg_path, ICONSET.parent.parent.parent / "Design/AppIcon" / f"{name}.svg")
            print(f"  {name}.svg")
            continue

        png_path = ICONSET / f"{name}.png"
        rasterise(chrome, svg_path, png_path, transparent=not opaque)
        width, height, has_alpha = png_info(png_path)

        if (width, height) != (PLATE, PLATE):
            sys.exit(f"{name}: expected {PLATE}x{PLATE}, got {width}x{height}")
        if opaque and has_alpha:
            sys.exit(f"{name}: light icon must not carry an alpha channel (App Store rejects it)")
        if not opaque and not has_alpha:
            sys.exit(f"{name}: dark/tinted icons must be transparent")

        print(f"  {name}.png  {width}x{height}  alpha={'yes' if has_alpha else 'no'}")

    shutil.rmtree(work, ignore_errors=True)
    print(f"\nWrote to {ICONSET.relative_to(REPO)}")


if __name__ == "__main__":
    main()
