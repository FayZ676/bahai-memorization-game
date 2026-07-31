#!/usr/bin/env python3
"""Deterministic achievement badge prompt generator.

Usage:  python3 Design/Badges/generate_badge_prompt.py <category> [level]
        python3 Design/Badges/generate_badge_prompt.py --list
        python3 Design/Badges/generate_badge_prompt.py --all

Given a category and (optionally) a level, produces the exact same image
generation prompt every time. All style decisions live in the registries
below, not in the function -- the function is pure template substitution
plus validation. See README.md for the layering rules and for how to add
a new category.
"""

from __future__ import annotations

import argparse
import sys
from typing import Optional


STYLE_ANCHOR = """A single achievement badge icon, {shape} shaped, {finish}. \
{detail_level}. The badge has a {border}, framing the central field. In \
the center: {icon}. Background color of the central field: {color}. \
Centered, front-facing, symmetrical composition. Isolated on a plain \
transparent or neutral background, no other objects in frame, no text, \
no readable letters or numbers unless explicitly requested."""


# `icon` has its own additive-only mechanism (icon_variation) precisely so a
# level can never silently replace a category's identity; `shape` is category
# identity for the same reason. Neither may appear in a level's `overrides`.
PROTECTED_OVERRIDE_KEYS = {"icon", "shape"}


GLOBAL = {
    "finish": (
        "cloisonné/enamel-pin technique, flat-to-subtly-shaded color "
        "regions separated by consistent-width metal cell walls, organic "
        "sculpted silhouette with flowing rounded shapes rather than "
        "geometric precision, mostly flat color fill with a touch of "
        "sheen for dimension, no heavy 3D bevel or glossy highlight, no "
        "photorealistic texture"
    ),
    "detail_level": (
        "Bold simplified silhouette, thick clean linework, minimal fine "
        "texture or gradient, strong contrast between icon and "
        "background, designed to stay legible at small mobile icon "
        "sizes (roughly 40-60px)"
    ),
}


LEVEL_REGISTRY = {
    1: {
        "border": "thin plain color rim band, same hue family as the "
                  "field but one shade lighter",
    },
    2: {
        "border": "color rim band with small evenly-spaced metal accent "
                  "dots circling it",
    },
    3: {
        "border": "color rim band with metal ray or laurel accents "
                  "circling it, more ornate",
    },
}


CATEGORY_REGISTRY = {
    "healing": {
        "shape": "circular",
        "icon": (
            "a simple ceramic bowl silhouette with one bold crack down "
            "the center, mended in a thick gold seam"
        ),
        "color": "soft teal",
        "levels": {
            1: {"label": "Novice"},
            2: {"label": "Practiced"},
            3: {"label": "Healer"},
        },
    },
    "obligatory_prayer": {
        "shape": "hexagonal",
        "icon": "a compass rose",
        "color": "deep indigo",
        "levels": {
            1: {"label": "Short"},
            2: {
                "label": "Medium",
                "icon_variation": (
                    "with a single ring of fine radiating lines around it"
                ),
            },
            3: {
                "label": "Long",
                "icon_variation": (
                    "with two concentric rings of fine radiating lines "
                    "around it, more ornate detailing on the needle"
                ),
            },
        },
    },
    "first_prayer_memorized": {
        "shape": "circular",
        "icon": "an open hand releasing a single small bird",
        "color": "warm gold",
        "border": "plain single ring",
    },
}


class BadgePromptError(ValueError):
    """Raised when a category/level combination can't be resolved."""


def _merge(base: dict, overrides: dict) -> dict:
    result = dict(base)
    result.update(overrides)
    return result


def generate_badge_prompt(category: str, level: Optional[int] = None) -> str:
    """Resolve a (category, level) pair into a ready-to-use image prompt.

    Raises BadgePromptError on any invalid or ambiguous input rather than
    guessing -- omitting a required level, passing a level to a non-leveled
    category, or naming an unregistered category or level.
    """
    if category not in CATEGORY_REGISTRY:
        known = ", ".join(sorted(CATEGORY_REGISTRY))
        raise BadgePromptError(f"unknown category '{category}' (known: {known})")

    cat = CATEGORY_REGISTRY[category]
    is_leveled = "levels" in cat

    resolved = {
        "shape": cat["shape"],
        "finish": GLOBAL["finish"],
        "detail_level": GLOBAL["detail_level"],
        "color": cat["color"],
        "icon": cat["icon"],
    }

    if is_leveled:
        if level is None:
            raise BadgePromptError(f"category '{category}' requires a level")
        if level not in cat["levels"]:
            raise BadgePromptError(f"category '{category}' has no level {level}")
        if level not in LEVEL_REGISTRY:
            raise BadgePromptError(f"level {level} has no entry in LEVEL_REGISTRY")

        level_entry = cat["levels"][level]
        resolved["border"] = LEVEL_REGISTRY[level]["border"]

        icon_variation = level_entry.get("icon_variation")
        if icon_variation:
            resolved["icon"] = f"{resolved['icon']}, {icon_variation}"

        overrides = level_entry.get("overrides", {})
        bad_keys = PROTECTED_OVERRIDE_KEYS & overrides.keys()
        if bad_keys:
            raise BadgePromptError(
                f"overrides for '{category}' level {level} illegally touch "
                f"protected field(s): {sorted(bad_keys)}. Use icon_variation "
                f"for icon changes; shape is not override-able."
            )
        resolved = _merge(resolved, overrides)
    else:
        if level is not None:
            raise BadgePromptError(
                f"category '{category}' has no levels -- level param not applicable"
            )
        resolved["border"] = cat["border"]

    return STYLE_ANCHOR.format(**resolved)


def all_badges() -> list[tuple[str, Optional[int], Optional[str]]]:
    """Every registered badge as (category, level, label), in registry order."""
    badges = []
    for category, cat in CATEGORY_REGISTRY.items():
        if "levels" in cat:
            for level in sorted(cat["levels"]):
                badges.append((category, level, cat["levels"][level].get("label")))
        else:
            badges.append((category, None, None))
    return badges


def _slug(category: str, level: Optional[int]) -> str:
    return category if level is None else f"{category}_{level}"


def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        description="Generate a deterministic achievement badge image prompt."
    )
    parser.add_argument("category", nargs="?", help="registered category name")
    parser.add_argument("level", nargs="?", type=int, help="level, for leveled categories")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--list", action="store_true", help="list every registered badge")
    group.add_argument("--all", action="store_true", help="print every badge prompt")
    args = parser.parse_args(argv)

    if args.list:
        for category, level, label in all_badges():
            suffix = f"  ({label})" if label else "  (no levels)"
            print(f"{_slug(category, level)}{suffix}")
        return 0

    if args.all:
        for index, (category, level, _) in enumerate(all_badges()):
            if index:
                print()
            print(f"# {_slug(category, level)}")
            print(generate_badge_prompt(category, level))
        return 0

    if not args.category:
        parser.error("give a category, or --list / --all")

    try:
        print(generate_badge_prompt(args.category, args.level))
    except BadgePromptError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
