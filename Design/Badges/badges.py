#!/usr/bin/env python3
"""Deterministic achievement badge prompts, driven by badges.json.

Usage:  python3 Design/Badges/badges.py prompt <category> [level]
        python3 Design/Badges/badges.py prompt --all
        python3 Design/Badges/badges.py list
        python3 Design/Badges/badges.py validate
        python3 Design/Badges/badges.py create <category> ...
        python3 Design/Badges/badges.py update <category> [level] ...
        python3 Design/Badges/badges.py delete <category> [--yes]

Style decisions live in badges.json; this file is template substitution plus
validation. See README.md for the layering rules and for how to add a badge.
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import sys
import tempfile
from typing import Any, Optional


CONFIG_PATH = pathlib.Path(__file__).resolve().parent / "badges.json"
SCHEMA_VERSION = 1

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
OVERRIDABLE_KEYS = {"finish", "detail_level", "color", "border"}

GLOBAL_KEYS = {"finish", "detail_level"}
CATEGORY_KEYS = {"shape", "icon", "color", "border", "levels"}
LEVEL_ENTRY_KEYS = {"label", "icon_variation", "overrides"}


class BadgePromptError(ValueError):
    """Raised when a category/level combination can't be resolved."""


class BadgeConfigError(ValueError):
    """Raised when badges.json is structurally invalid."""


def load_config(path: pathlib.Path = CONFIG_PATH) -> dict:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise BadgeConfigError(f"no config at {path}")
    except json.JSONDecodeError as error:
        raise BadgeConfigError(f"{path} is not valid JSON: {error}")
    config = _normalize_levels(raw)
    validate_config(config)
    return config


def save_config(config: dict, path: pathlib.Path = CONFIG_PATH) -> None:
    """Validate, then replace the config atomically so a crash can't truncate it."""
    validate_config(config)
    payload = json.dumps(_denormalize_levels(config), indent=2, ensure_ascii=False)
    handle, temp_path = tempfile.mkstemp(dir=str(path.parent), suffix=".json")
    try:
        with os.fdopen(handle, "w", encoding="utf-8") as stream:
            stream.write(payload + "\n")
        os.replace(temp_path, path)
    except BaseException:
        pathlib.Path(temp_path).unlink(missing_ok=True)
        raise


def _normalize_levels(config: Any) -> dict:
    if not isinstance(config, dict):
        raise BadgeConfigError("config root must be an object")
    result = dict(config)
    result["levels"] = _int_keyed(config.get("levels", {}), "levels")
    categories = {}
    for name, category in (config.get("categories") or {}).items():
        if not isinstance(category, dict):
            raise BadgeConfigError(f"category '{name}' must be an object")
        category = dict(category)
        if "levels" in category:
            category["levels"] = _int_keyed(category["levels"], f"category '{name}' levels")
        categories[name] = category
    result["categories"] = categories
    return result


def _denormalize_levels(config: dict) -> dict:
    result = dict(config)
    result["levels"] = {str(k): v for k, v in sorted(config["levels"].items())}
    categories = {}
    for name, category in config["categories"].items():
        category = dict(category)
        if "levels" in category:
            category["levels"] = {str(k): v for k, v in sorted(category["levels"].items())}
        categories[name] = category
    result["categories"] = categories
    return result


def _int_keyed(mapping: Any, label: str) -> dict:
    if not isinstance(mapping, dict):
        raise BadgeConfigError(f"{label} must be an object")
    result = {}
    for key, value in mapping.items():
        try:
            level = int(key)
        except (TypeError, ValueError):
            raise BadgeConfigError(f"{label}: '{key}' is not a level number")
        if level < 1:
            raise BadgeConfigError(f"{label}: level {level} must be 1 or greater")
        result[level] = value
    return result


def validate_config(config: dict) -> None:
    problems: list[str] = []

    if config.get("schema_version") != SCHEMA_VERSION:
        problems.append(
            f"schema_version must be {SCHEMA_VERSION}, got {config.get('schema_version')!r}"
        )

    global_block = config.get("global")
    if not isinstance(global_block, dict):
        problems.append("'global' must be an object")
    else:
        for key in sorted(GLOBAL_KEYS - global_block.keys()):
            problems.append(f"global is missing '{key}'")
        for key in sorted(global_block.keys() - GLOBAL_KEYS):
            problems.append(f"global has unknown key '{key}'")

    levels = config.get("levels") or {}
    for level, entry in sorted(levels.items()):
        if not isinstance(entry, dict) or not entry.get("border"):
            problems.append(f"levels.{level} needs a 'border'")

    for name, category in (config.get("categories") or {}).items():
        problems.extend(_category_problems(name, category, levels))

    if problems:
        raise BadgeConfigError("invalid config:\n  - " + "\n  - ".join(problems))


def _category_problems(name: str, category: dict, levels: dict) -> list[str]:
    problems = []
    for key in ("shape", "icon", "color"):
        if not category.get(key):
            problems.append(f"category '{name}' is missing '{key}'")
    for key in sorted(category.keys() - CATEGORY_KEYS):
        problems.append(f"category '{name}' has unknown key '{key}'")

    is_leveled = "levels" in category
    if is_leveled and category.get("border"):
        problems.append(
            f"category '{name}' is leveled, so its border comes from the level "
            f"registry -- remove the category-level 'border'"
        )
    if not is_leveled and not category.get("border"):
        problems.append(f"category '{name}' has no levels, so it needs its own 'border'")

    if not is_leveled:
        return problems

    if not category["levels"]:
        problems.append(f"category '{name}' has an empty 'levels'")
    for level, entry in sorted(category["levels"].items()):
        where = f"category '{name}' level {level}"
        if level not in levels:
            problems.append(f"{where} has no entry in the level registry")
        if not isinstance(entry, dict):
            problems.append(f"{where} must be an object")
            continue
        if not entry.get("label"):
            problems.append(f"{where} is missing 'label'")
        for key in sorted(entry.keys() - LEVEL_ENTRY_KEYS):
            problems.append(f"{where} has unknown key '{key}'")
        problems.extend(_override_problems(where, entry.get("overrides") or {}))
    return problems


def _override_problems(where: str, overrides: Any) -> list[str]:
    if not isinstance(overrides, dict):
        return [f"{where} 'overrides' must be an object"]
    problems = []
    protected = PROTECTED_OVERRIDE_KEYS & overrides.keys()
    if protected:
        problems.append(
            f"{where} overrides illegally touch protected field(s): {sorted(protected)}. "
            f"Use icon_variation for icon changes; shape is not override-able."
        )
    for key in sorted(overrides.keys() - OVERRIDABLE_KEYS - PROTECTED_OVERRIDE_KEYS):
        problems.append(f"{where} overrides unknown field '{key}'")
    return problems


def generate_badge_prompt(config: dict, category: str, level: Optional[int] = None) -> str:
    """Resolve a (category, level) pair into a ready-to-use image prompt.

    Raises BadgePromptError on any invalid or ambiguous input rather than
    guessing -- omitting a required level, passing a level to a non-leveled
    category, or naming an unregistered category or level.
    """
    categories = config["categories"]
    if category not in categories:
        known = ", ".join(sorted(categories))
        raise BadgePromptError(f"unknown category '{category}' (known: {known})")

    cat = categories[category]
    resolved = {
        "shape": cat["shape"],
        "finish": config["global"]["finish"],
        "detail_level": config["global"]["detail_level"],
        "color": cat["color"],
        "icon": cat["icon"],
    }

    if "levels" in cat:
        if level is None:
            raise BadgePromptError(f"category '{category}' requires a level")
        if level not in cat["levels"]:
            raise BadgePromptError(f"category '{category}' has no level {level}")

        entry = cat["levels"][level]
        resolved["border"] = config["levels"][level]["border"]
        if entry.get("icon_variation"):
            resolved["icon"] = f"{resolved['icon']}, {entry['icon_variation']}"
        resolved.update(entry.get("overrides") or {})
    else:
        if level is not None:
            raise BadgePromptError(
                f"category '{category}' has no levels -- level param not applicable"
            )
        resolved["border"] = cat["border"]

    return STYLE_ANCHOR.format(**resolved)


def all_badges(config: dict) -> list[tuple[str, Optional[int], Optional[str]]]:
    """Every registered badge as (category, level, label), in registry order."""
    badges = []
    for name, category in config["categories"].items():
        if "levels" in category:
            for level in sorted(category["levels"]):
                badges.append((name, level, category["levels"][level].get("label")))
        else:
            badges.append((name, None, None))
    return badges


def _slug(category: str, level: Optional[int]) -> str:
    return category if level is None else f"{category}_{level}"


def _parse_level_flag(raw: str) -> tuple[int, dict]:
    number, _, rest = raw.partition("=")
    if not rest:
        raise BadgePromptError(f"--level must look like 'N=Label', got '{raw}'")
    try:
        level = int(number)
    except ValueError:
        raise BadgePromptError(f"--level number '{number}' is not an integer")
    label, _, variation = rest.partition("|")
    entry = {"label": label.strip()}
    if variation.strip():
        entry["icon_variation"] = variation.strip()
    return level, entry


def cmd_prompt(config: dict, args) -> int:
    if args.all:
        for index, (category, level, _) in enumerate(all_badges(config)):
            if index:
                print()
            print(f"# {_slug(category, level)}")
            print(generate_badge_prompt(config, category, level))
        return 0
    if not args.category:
        raise BadgePromptError("give a category, or --all")
    print(generate_badge_prompt(config, args.category, args.level))
    return 0


def cmd_list(config: dict, args) -> int:
    for category, level, label in all_badges(config):
        suffix = f"  ({label})" if label else "  (no levels)"
        print(f"{_slug(category, level)}{suffix}")
    return 0


def cmd_validate(config: dict, args) -> int:
    print(f"badges.json is valid: {len(config['categories'])} categories, "
          f"{len(all_badges(config))} badges")
    return 0


def cmd_create(config: dict, args) -> int:
    if args.category in config["categories"]:
        raise BadgePromptError(
            f"category '{args.category}' already exists -- use 'update' to change it"
        )
    category: dict = {"shape": args.shape, "icon": args.icon, "color": args.color}
    if args.level:
        category["levels"] = dict(_parse_level_flag(raw) for raw in args.level)
    elif args.border:
        category["border"] = args.border
    else:
        raise BadgePromptError(
            "give --level for a leveled category, or --border for a binary one"
        )
    if args.level and args.border:
        raise BadgePromptError("a leveled category takes its border from the level registry")

    config["categories"][args.category] = category
    save_config(config)
    print(f"created '{args.category}'")
    _print_prompts(config, args.category, None)
    return 0


def cmd_update(config: dict, args) -> int:
    if args.category not in config["categories"]:
        raise BadgePromptError(f"unknown category '{args.category}'")
    category = config["categories"][args.category]

    if args.level is None:
        if args.label or args.icon_variation:
            raise BadgePromptError("--label and --icon-variation need a level")
        changes = _changes({"shape": args.shape, "icon": args.icon,
                            "color": args.color, "border": args.border})
        if not changes:
            raise BadgePromptError("nothing to update -- pass at least one field")
        if "levels" in category and "border" in changes:
            raise BadgePromptError(
                f"category '{args.category}' is leveled, so its border comes from the "
                f"level registry -- set it on a level instead"
            )
        category.update(changes)
    else:
        if "levels" not in category:
            raise BadgePromptError(f"category '{args.category}' has no levels")
        if args.level not in category["levels"]:
            raise BadgePromptError(f"category '{args.category}' has no level {args.level}")
        if args.shape or args.icon:
            raise BadgePromptError(
                "shape and icon are protected at the level layer. Use --icon-variation "
                "to elaborate the icon, or update the category without a level."
            )
        entry = category["levels"][args.level]
        fields = _changes({"label": args.label, "icon_variation": args.icon_variation})
        overrides = _changes({"color": args.color, "border": args.border})
        if not fields and not overrides:
            raise BadgePromptError("nothing to update -- pass at least one field")
        entry.update(fields)
        if overrides:
            entry["overrides"] = {**(entry.get("overrides") or {}), **overrides}

    save_config(config)
    print(f"updated '{_slug(args.category, args.level)}'")
    _print_prompts(config, args.category, args.level)
    return 0


def _changes(candidates: dict) -> dict:
    return {key: value for key, value in candidates.items() if value is not None}


def _print_prompts(config: dict, category: str, level: Optional[int]) -> None:
    """Show what a mutation produced -- every level when the change was category-wide."""
    entry = config["categories"][category]
    if level is None and "levels" in entry:
        levels: list[Optional[int]] = sorted(entry["levels"])
    else:
        levels = [level]
    for index, each in enumerate(levels):
        if index:
            print()
        print(generate_badge_prompt(config, category, each))


def cmd_delete(config: dict, args) -> int:
    if args.category not in config["categories"]:
        raise BadgePromptError(f"unknown category '{args.category}'")

    badges = [b for b in all_badges(config) if b[0] == args.category]
    if not args.yes:
        if not sys.stdin.isatty():
            raise BadgePromptError(
                f"deleting '{args.category}' removes {len(badges)} badge(s) and any "
                f"already-earned achievement loses its definition. Re-run with --yes "
                f"to confirm."
            )
        print(f"Delete '{args.category}' and its {len(badges)} badge(s)?")
        print("Any already-earned achievement loses its name and art definition.")
        if input("Type the category name to confirm: ").strip() != args.category:
            print("aborted")
            return 1

    del config["categories"][args.category]
    save_config(config)
    print(f"deleted '{args.category}'")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    subs = parser.add_subparsers(dest="command", required=True)

    prompt = subs.add_parser("prompt", help="print a badge's image prompt")
    prompt.add_argument("category", nargs="?")
    prompt.add_argument("level", nargs="?", type=int)
    prompt.add_argument("--all", action="store_true", help="every prompt, labelled")
    prompt.set_defaults(func=cmd_prompt)

    listing = subs.add_parser("list", help="list every registered badge")
    listing.set_defaults(func=cmd_list)

    check = subs.add_parser("validate", help="check badges.json against the schema")
    check.set_defaults(func=cmd_validate)

    create = subs.add_parser("create", help="add a category")
    create.add_argument("category")
    create.add_argument("--shape", required=True)
    create.add_argument("--icon", required=True)
    create.add_argument("--color", required=True)
    create.add_argument("--border", help="binary categories only")
    create.add_argument("--level", action="append", metavar="N=Label[|variation]")
    create.set_defaults(func=cmd_create)

    update = subs.add_parser("update", help="change a category or one of its levels")
    update.add_argument("category")
    update.add_argument("level", nargs="?", type=int)
    update.add_argument("--shape")
    update.add_argument("--icon")
    update.add_argument("--color")
    update.add_argument("--border")
    update.add_argument("--label", help="level scope only")
    update.add_argument("--icon-variation", dest="icon_variation", help="level scope only")
    update.set_defaults(func=cmd_update)

    delete = subs.add_parser("delete", help="remove a category outright")
    delete.add_argument("category")
    delete.add_argument("--yes", action="store_true", help="skip the confirmation prompt")
    delete.set_defaults(func=cmd_delete)

    return parser


def main(argv: Optional[list[str]] = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        return args.func(load_config(), args)
    except (BadgePromptError, BadgeConfigError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
