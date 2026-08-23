#!/usr/bin/env python3
"""Compose App Store preview tiles: a headline over a bezelled phone.

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
    headline_lift=0.022,    # optical bias above dead centre of the band
    headline_size=0.089,    # em, as a fraction of canvas width
    headline_leading=1.06,
    phone_top=0.165,
    phone_width=0.852,
    bezel=0.0114,           # bezel thickness, fraction of canvas width
    radius=0.0742,          # outer corner radius, fraction of canvas width
)

IPHONE = dict(size=(1320, 2868), folder="iphone-6.9", geometry=GEOMETRY)
IPAD = dict(size=(2064, 2752), folder="ipad-13", geometry=dict(
    GEOMETRY,
    headline_lift=0.018,
    headline_size=0.062,
    phone_top=0.230,
    phone_width=0.780,
    bezel=0.0080,
    radius=0.0520,
))

# One pass through the app, in order: pick a prayer, hide a word, hide more, say it aloud,
# know it. Tiles 2 and 3 are deliberately the same chunk of the same passage at two stages,
# so the sequence shows the thing getting harder instead of describing it — the recitation
# beat follows that pair rather than splitting it. The closing tile is dark because that is
# the only place a theme can be shown without spending a tile on it; the iPad was never
# shot in dark, so it falls back to the light library through per_device rather than
# dropping the beat entirely.
TILES = [
    dict(name="1-choose.png", source="3-built-in-library.png",
         headline="Start with any\nof 225 prayers."),
    dict(name="2-hide.png", source="2-hide-words.png",
         headline="Tap a word\nto hide it."),
    dict(name="3-hide-more.png", source="9-hide-more.png",
         headline="Hide more\neach time you return."),
    dict(name="4-recite.png", source="recite-aloud.png",
         headline="Then say it\nout loud."),
    dict(name="5-know.png", source="6-library-dark.png", theme="dark",
         headline="Until you know it\nby heart.",
         per_device={"ipad-13": dict(source="1-library.png", theme="light")}),
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
    top: 0;
    left: 0;
    width: {w}px;
    height: {phone_top}px;
    padding-bottom: {headline_lift}px;
    display: flex;
    align-items: center;
    justify-content: center;
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
<div class="copy"><h1>{headline}</h1></div>
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


def resolve(tile, device):
    return dict(tile, **tile.get("per_device", {}).get(device["folder"], {}))


def build_page(tile, device):
    tile = resolve(tile, device)
    width, height = device["size"]
    geo = dict(device["geometry"], **tile.get("geometry", {}))
    theme = DARK if tile.get("theme") == "dark" else LIGHT
    source = SHOTS / device["folder"] / tile["source"]

    phone_width = round(width * geo["phone_width"])
    bezel = round(width * geo["bezel"])
    phone_top = round(height * geo["phone_top"])

    return PAGE.format(
        w=width, h=height,
        display_font=(FONTS / "EBGaramond-Bold.ttf").as_uri(),
        ground=theme["ground"], ink=theme["ink"], muted=theme["muted"],
        bezel=theme["bezel"], shadow=theme["shadow"], rim=theme["rim"],
        lift=0.022 if tile.get("theme") != "dark" else 0.0,
        headline_lift=round(height * geo["headline_lift"]),
        headline_size=round(width * geo["headline_size"]),
        headline_leading=geo["headline_leading"],
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
    parser.add_argument("--only", help="substring of a tile's name or source filename")
    parser.add_argument("--html-only", action="store_true")
    args = parser.parse_args()

    devices = {"iphone": [IPHONE], "ipad": [IPAD], "both": [IPHONE, IPAD]}[args.device]
    chrome = None if args.html_only else find_chrome()
    work = pathlib.Path(tempfile.mkdtemp(prefix="verses-frames-"))

    for device in devices:
        out_dir = SHOTS / f"{device['folder']}-framed"
        out_dir.mkdir(parents=True, exist_ok=True)
        for tile in TILES:
            source = resolve(tile, device)["source"]
            if args.only and args.only not in tile["name"] + source:
                continue
            if not (SHOTS / device["folder"] / source).exists():
                continue
            page = work / f"{device['folder']}-{tile['name']}.html"
            page.write_text(build_page(tile, device))
            if args.html_only:
                print("html:", page)
                continue
            out = out_dir / tile["name"]
            rasterise(chrome, page, out, device["size"])
            got = png_size(out)
            if got != tuple(device["size"]):
                sys.exit(f"{out.name} came out {got}, expected {tuple(device['size'])}")
            print(f"{device['folder']}-framed/{out.name}  {got[0]}x{got[1]}")


if __name__ == "__main__":
    main()
