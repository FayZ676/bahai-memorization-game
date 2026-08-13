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

FADE_START, FADE_MID, FADE_END = 0.15, 0.63, 0.92
FADE_MID_ALPHA = 0.16
FADE_S_AMPLITUDE = 0.11
FADE_S_PHASE = 0.5
FADE_STRIPS = 128

_COS = [math.cos(math.radians(-90 + (360 / POINTS) * k)) for k in range(POINTS)]
_SIN = [math.sin(math.radians(-90 + (360 / POINTS) * k)) for k in range(POINTS)]
XMIN = CX + min(_COS) * RADIUS - STROKE_HALF
SPAN = (CX + max(_COS) * RADIUS + STROKE_HALF) - XMIN
YMIN = CY + min(_SIN) * RADIUS - STROKE_HALF
YSPAN = (CY + max(_SIN) * RADIUS + STROKE_HALF) - YMIN

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


def fade_mask(uid):
    mid_offset = (FADE_MID - FADE_START) / (FADE_END - FADE_START)
    mid_hex = "%02X" % round(FADE_MID_ALPHA * 255)
    stops = (f'<stop offset="0" stop-color="#FFFFFF"/>'
             f'<stop offset="{mid_offset:.3f}" stop-color="#{mid_hex}{mid_hex}{mid_hex}"/>'
             f'<stop offset="1" stop-color="#000000"/>')

    height = PLATE / FADE_STRIPS
    defs, rects = [], []
    for k in range(FADE_STRIPS):
        y = (k + 0.5) * height
        t = min(1.0, max(0.0, (y - YMIN) / YSPAN))
        shift = FADE_S_AMPLITUDE * SPAN * math.sin(2 * math.pi * (t + FADE_S_PHASE))
        x1 = XMIN + FADE_START * SPAN + shift
        x2 = XMIN + FADE_END * SPAN + shift
        defs.append(f'<linearGradient id="fadeG{uid}{k}" gradientUnits="userSpaceOnUse" '
                    f'x1="{x1:.1f}" y1="0" x2="{x2:.1f}" y2="0">{stops}</linearGradient>')
        rects.append(f'<rect x="0" y="{k * height:.2f}" width="{PLATE}" '
                     f'height="{height + 1:.2f}" shape-rendering="crispEdges" '
                     f'fill="url(#fadeG{uid}{k})"/>')

    return ("".join(defs)
            + f'<mask id="fade{uid}" maskUnits="userSpaceOnUse" x="0" y="0" '
              f'width="{PLATE}" height="{PLATE}">' + "".join(rects) + '</mask>')


def render_svg(uid, green, foil, ground, shadow, fade=True):
    pts = star_points()
    foil_stops = "".join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in foil)

    dx, dy = FOIL_DIR
    length = math.hypot(dx, dy)
    dx, dy = dx / length * FOIL_PERIOD, dy / length * FOIL_PERIOD

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

    fade_def = fade_mask(uid) if fade else ""
    fade_use = f' mask="url(#fade{uid})"' if fade else ""

    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {PLATE} {PLATE}" width="{PLATE}" height="{PLATE}">
<defs>
  {ground_def}
  <linearGradient id="foil{uid}" gradientUnits="userSpaceOnUse" spreadMethod="reflect"
    x1="{XMIN:.1f}" y1="0" x2="{XMIN + dx:.1f}" y2="{dy:.1f}">{foil_stops}</linearGradient>
  {fade_def}
  {shadow_def}
</defs>
{ground_use}
<g{fade_use}>
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


PREVIEWS = {
    "Light-Fade": dict(VARIANTS["AppIcon"], uid="pltf", fade=True),
    "Light-Plain": dict(VARIANTS["AppIcon"], uid="pltp", fade=False),
    "Dark-Fade": dict(VARIANTS["AppIcon-Dark"], uid="pdkf", fade=True),
    "Dark-Plain": dict(VARIANTS["AppIcon-Dark"], uid="pdkp", fade=False),
}

PREVIEW_DIR = pathlib.Path(__file__).resolve().parent / "previews"


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
    parser.add_argument("--previews", action="store_true")
    args = parser.parse_args()

    work = pathlib.Path(tempfile.mkdtemp(prefix="verses-icon-"))
    chrome = None if args.svg_only else find_chrome()

    if args.previews:
        PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
        for name, spec in PREVIEWS.items():
            spec = dict(spec)
            opaque = spec.pop("opaque")
            svg_path = work / f"{name}.svg"
            svg_path.write_text(render_svg(**spec))
            png_path = PREVIEW_DIR / f"AppIcon-{name}.png"
            rasterise(chrome, svg_path, png_path, transparent=not opaque)
            width, height, has_alpha = png_info(png_path)
            print(f"  AppIcon-{name}.png  {width}x{height}  alpha={'yes' if has_alpha else 'no'}")
        shutil.rmtree(work, ignore_errors=True)
        print(f"\nWrote to {PREVIEW_DIR.relative_to(REPO)}")
        return

    ICONSET.mkdir(parents=True, exist_ok=True)

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
