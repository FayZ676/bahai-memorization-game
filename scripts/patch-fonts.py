#!/usr/bin/env python3
"""Add the transliteration letters EB Garamond ships without.

The bundled EB Garamond has no precomposed dot-below letters (ḥ, Ṭ, ẓ, ...), so iOS
draws them in a fallback face. This builds each one as a composite of the base
letter and the font's own dotbelowcomb, placed by the font's mark-to-base anchors,
and maps the Unicode hyphens (U+2010, U+2011) to the plain hyphen glyph.

Idempotent: run it again after replacing the fonts.

    python3 scripts/patch-fonts.py
"""

import glob
import os
import unicodedata

from fontTools.ttLib import TTFont
from fontTools.ttLib.tables._g_l_y_f import Glyph, GlyphComponent

FONTS = os.path.join(os.path.dirname(__file__), "..", "MemorizationGame", "Resources", "Fonts", "*.ttf")
DOT_BELOW = 0x0323
HYPHEN_ALIASES = [0x2010, 0x2011]


def dot_below_letters():
    for code in range(0x1E00, 0x1F00):
        parts = unicodedata.normalize("NFD", chr(code))
        if len(parts) == 2 and ord(parts[1]) == DOT_BELOW:
            yield code, ord(parts[0])


def mark_to_base_tables(font, mark):
    for lookup in font["GPOS"].table.LookupList.Lookup:
        if lookup.LookupType != 4:
            continue
        for sub in lookup.SubTable:
            if mark in sub.MarkCoverage.glyphs:
                yield sub, sub.MarkArray.MarkRecord[sub.MarkCoverage.glyphs.index(mark)]


def anchor_offset(font, base, mark):
    """The font's own anchors where it has them; capitals have none, so centre the dot."""
    records = list(mark_to_base_tables(font, mark))
    for sub, record in records:
        if base not in sub.BaseCoverage.glyphs:
            continue
        anchor = sub.BaseArray.BaseRecord[sub.BaseCoverage.glyphs.index(base)].BaseAnchor[record.Class]
        if anchor is not None:
            return (
                anchor.XCoordinate - record.MarkAnchor.XCoordinate,
                anchor.YCoordinate - record.MarkAnchor.YCoordinate,
            )
    if not records:
        return None
    outline = font["glyf"][base]
    outline.recalcBounds(font["glyf"])
    return (outline.xMin + outline.xMax) // 2 - records[0][1].MarkAnchor.XCoordinate, 0


def component(name, x, y):
    part = GlyphComponent()
    part.glyphName = name
    part.x, part.y = x, y
    part.flags = 0
    return part


def patch(path):
    font = TTFont(path)
    cmap = font.getBestCmap()
    glyf, hmtx = font["glyf"], font["hmtx"]
    mark = cmap[DOT_BELOW]
    added = {}

    for code, base_code in dot_below_letters():
        if code in cmap or base_code not in cmap:
            continue
        base = cmap[base_code]
        offset = anchor_offset(font, base, mark)
        if offset is None:
            continue
        name = f"uni{code:04X}"
        glyph = Glyph()
        glyph.numberOfContours = -1
        glyph.components = [component(base, 0, 0), component(mark, *offset)]
        glyph.components[0].flags = 0x0200
        glyf[name] = glyph
        hmtx[name] = hmtx[base]
        added[code] = name

    for code in HYPHEN_ALIASES:
        if code not in cmap:
            added[code] = cmap[ord("-")]

    if not added:
        print(f"{os.path.basename(path)}: already patched")
        return

    font.setGlyphOrder(font.getGlyphOrder() + [n for n in added.values() if n not in font.getGlyphOrder()])
    for table in font["cmap"].tables:
        if table.isUnicode():
            table.cmap.update(added)
    font.save(path)
    print(f"{os.path.basename(path)}: added {len(added)} characters")


for path in sorted(glob.glob(FONTS)):
    patch(path)
