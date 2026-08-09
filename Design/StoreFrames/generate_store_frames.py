#!/usr/bin/env python3
"""Compose App Store preview tiles: headline, subhead, and a bezelled phone.

Reads the raw screenshots in store-screenshots/ and writes framed tiles beside
them. Requires headless Chrome to rasterise; set CHROME to override the path.
"""

import argparse
import base64
import os
import pathlib
import struct
import subprocess
import sys
import tempfile

REPO = pathlib.Path(__file__).resolve().parents[2]
SHOTS = REPO / "store-screenshots"
FONTS = REPO / "MemorizationGame" / "Resources" / "Fonts"

CHROME_CANDIDATES = [
    os.environ.get("CHROME", ""),
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
]

LIGHT = dict(ground="#ECEEE8", ink="#1C2521", muted="#6A716B",
             bezel="#0B0B0B", shadow="rgba(28,37,33,0.20)",
             rim="rgba(255,255,255,0)")
# on the dark ground a black bezel vanishes, so the silhouette is drawn by a rim
DARK = dict(ground="#121212", ink="#EDEDED", muted="#9A9A9A",
            bezel="#000000", shadow="rgba(0,0,0,0.55)",
            rim="rgba(255,255,255,0.16)")

# Proportions lifted off the reference tile, as fractions of the canvas.
GEOMETRY = dict(
    headline_top=0.069,     # top of the headline's cap height
    headline_size=0.089,    # em, as a fraction of canvas width
    headline_leading=1.06,
    subhead_gap=0.0105,     # headline block to subhead
    subhead_size=0.0365,
    subhead_leading=1.37,
    subhead_width=0.88,     # measure, as a fraction of canvas width
    phone_top=0.251,
    phone_width=0.852,
    bezel=0.0114,           # bezel thickness, fraction of canvas width
    radius=0.0742,          # outer corner radius, fraction of canvas width
)

IPHONE = dict(size=(1320, 2868), folder="iphone-6.9", geometry=GEOMETRY)
IPAD = dict(size=(2064, 2752), folder="ipad-13", geometry=dict(
    GEOMETRY,
    headline_top=0.055,
    headline_size=0.062,
    subhead_size=0.0255,
    subhead_gap=0.021,
    phone_top=0.230,
    phone_width=0.780,
    bezel=0.0080,
    radius=0.0520,
))

TILES = [
    dict(source="1-library.png",
         headline="See everything\nyou’re memorizing.",
         subhead="Every passage you’ve added, and how much of it you know so far."),
    dict(source="2-hide-words.png",
         headline="Tap a word\nto hide it.",
         subhead="Read what’s left out loud. Hide a few more each time you come back."),
    dict(source="3-built-in-library.png",
         headline="225 prayers,\nbuilt in.",
         subhead="All 153 Hidden Words and 24 Ruhi passages too. Or paste your own text."),
    dict(source="4-preview.png",
         headline="Read a prayer\nbefore you start.",
         subhead="Open anything in the library and read it through first."),
    dict(source="5-dark.png", theme="dark",
         headline="Works in dark mode.",
         subhead="No account and no ads. Reminders only if you turn them on."),
    dict(source="6-library-dark.png", theme="dark",
         headline="Everything stays\non your iPhone.",
         subhead="No sign-in, no sync, no tracking."),
    dict(source="7-hidden-words.png",
         headline="All 153\nHidden Words.",
         subhead="From the Arabic and from the Persian, complete and searchable."),
    dict(source="8-achievements.png",
         headline="Seven achievements\nto earn.",
         subhead="Memorize an obligatory prayer, a healing prayer, five Hidden Words, and more."),
]

PAGE = """<!doctype html>
<meta charset="utf-8">
<style>
  @font-face {{
    font-family: "Display";
    src: url("{display_font}") format("truetype");
    font-weight: 700;
  }}
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  html, body {{ width: {w}px; height: {h}px; overflow: hidden; }}
  body {{
    background: {ground};
    background-image: linear-gradient(180deg,
      rgba(0,0,0,0) 0%, rgba(0,0,0,{lift}) 100%);
    -webkit-font-smoothing: antialiased;
    text-rendering: geometricPrecision;
  }}
  .copy {{
    position: absolute;
    top: {headline_top}px;
    left: 0;
    width: {w}px;
    text-align: center;
  }}
  h1 {{
    font-family: "Display", Georgia, serif;
    font-weight: 700;
    font-size: {headline_size}px;
    line-height: {headline_leading};
    letter-spacing: -0.004em;
    color: {ink};
    white-space: pre-line;
  }}
  p {{
    margin: {subhead_gap}px auto 0;
    max-width: {subhead_width}px;
    font-family: -apple-system, "Helvetica Neue", Helvetica, sans-serif;
    font-weight: 400;
    font-size: {subhead_size}px;
    line-height: {subhead_leading};
    letter-spacing: 0.002em;
    color: {muted};
  }}
  .phone {{
    position: absolute;
    top: {phone_top}px;
    left: {phone_left}px;
    width: {phone_width}px;
    height: {phone_height}px;
    background: {bezel};
    border-radius: {radius}px {radius}px 0 0;
    padding: {bezel_px}px {bezel_px}px 0;
    box-shadow: 0 {shadow_y}px {shadow_blur}px {shadow}, inset 0 0 0 2px {rim};
  }}
  .screen {{
    width: 100%;
    height: 100%;
    border-radius: {inner_radius}px {inner_radius}px 0 0;
    overflow: hidden;
    background: {ground};
  }}
  .screen img {{ display: block; width: 100%; }}
</style>
<div class="copy">
  <h1>{headline}</h1>
  {subhead_html}
</div>
<div class="phone"><div class="screen"><img src="{shot}"></div></div>
"""


def find_chrome():
    for candidate in CHROME_CANDIDATES:
        if candidate and pathlib.Path(candidate).exists():
            return candidate
    sys.exit("Could not find Chrome. Set CHROME=/path/to/chrome and retry.")


def png_size(path):
    with open(path, "rb") as handle:
        header = handle.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path} is not a PNG")
    return struct.unpack(">II", header[16:24])


def data_uri(path):
    return "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode()


def build_page(tile, device):
    width, height = device["size"]
    geo = device["geometry"]
    theme = DARK if tile.get("theme") == "dark" else LIGHT
    source = SHOTS / device["folder"] / tile["source"]

    phone_width = round(width * geo["phone_width"])
    bezel = round(width * geo["bezel"])
    phone_top = round(height * geo["phone_top"])

    subhead = tile.get("subhead")
    return PAGE.format(
        w=width, h=height,
        display_font=(FONTS / "CormorantGaramond-Bold.ttf").as_uri(),
        ground=theme["ground"], ink=theme["ink"], muted=theme["muted"],
        bezel=theme["bezel"], shadow=theme["shadow"], rim=theme["rim"],
        lift=0.022 if tile.get("theme") != "dark" else 0.0,
        headline_top=round(height * geo["headline_top"]),
        headline_size=round(width * geo["headline_size"]),
        headline_leading=geo["headline_leading"],
        subhead_gap=round(height * geo["subhead_gap"]),
        subhead_size=round(width * geo["subhead_size"]),
        subhead_leading=geo["subhead_leading"],
        subhead_width=round(width * geo["subhead_width"]),
        phone_top=phone_top,
        phone_left=round((width - phone_width) / 2),
        phone_width=phone_width,
        phone_height=height - phone_top,
        bezel_px=bezel,
        radius=round(width * geo["radius"]),
        inner_radius=round(width * geo["radius"]) - bezel,
        shadow_y=round(width * 0.010),
        shadow_blur=round(width * 0.034),
        headline=tile["headline"],
        subhead_html=f"<p>{subhead}</p>" if subhead else "",
        shot=data_uri(source),
    )


def rasterise(chrome, page, out, size):
    subprocess.run([
        chrome, "--headless", "--disable-gpu", "--force-device-scale-factor=1",
        "--hide-scrollbars", f"--screenshot={out}",
        f"--window-size={size[0]},{size[1]}", page.as_uri(),
    ], check=True, capture_output=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--device", choices=["iphone", "ipad", "both"], default="iphone")
    parser.add_argument("--only", help="substring of a source filename")
    parser.add_argument("--html-only", action="store_true")
    args = parser.parse_args()

    devices = {"iphone": [IPHONE], "ipad": [IPAD], "both": [IPHONE, IPAD]}[args.device]
    chrome = None if args.html_only else find_chrome()
    work = pathlib.Path(tempfile.mkdtemp(prefix="verses-frames-"))

    for device in devices:
        out_dir = SHOTS / f"{device['folder']}-framed"
        out_dir.mkdir(parents=True, exist_ok=True)
        for tile in TILES:
            if args.only and args.only not in tile["source"]:
                continue
            if not (SHOTS / device["folder"] / tile["source"]).exists():
                continue
            page = work / f"{device['folder']}-{tile['source']}.html"
            page.write_text(build_page(tile, device))
            if args.html_only:
                print("html:", page)
                continue
            out = out_dir / tile["source"]
            rasterise(chrome, page, out, device["size"])
            got = png_size(out)
            if got != tuple(device["size"]):
                sys.exit(f"{out.name} came out {got}, expected {tuple(device['size'])}")
            print(f"{device['folder']}-framed/{out.name}  {got[0]}x{got[1]}")


if __name__ == "__main__":
    main()
