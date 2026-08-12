#!/usr/bin/env python3
import collections
import json
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
LIBRARY = REPO / "MemorizationGame" / "Resources" / "library.json"
LISTING = REPO / "store-listing.md"

CLAIMS = [
    (r"(\d+) prayers", "Prayers"),
    (r"[Hh]idden [Ww]ords[^.\n]*?, all (\d+)", "The Hidden Words"),
    (r"all (\d+) Hidden Words", "The Hidden Words"),
    (r"(\d+) Ruhi quotations", "Ruhi"),
]


def main():
    entries = json.loads(LIBRARY.read_text())["entries"]
    counts = collections.Counter(entry.get("collection", "?") for entry in entries)
    listing = LISTING.read_text()

    print("library.json:")
    for collection, count in counts.most_common():
        print(f"  {collection}: {count}")
    print()

    problems = []
    checked = 0
    for pattern, collection in CLAIMS:
        for match in re.finditer(pattern, listing):
            checked += 1
            claimed = int(match.group(1))
            actual = counts.get(collection, 0)
            line = listing[: match.start()].count("\n") + 1
            status = "ok" if claimed == actual else "STALE"
            print(f"  {status}  store-listing.md:{line}  {match.group(0)!r} vs {actual} in {collection}")
            if claimed != actual:
                problems.append((line, match.group(0), actual, collection))

    print()
    if not checked:
        print("No numeric claims matched — the listing's wording may have changed; check CLAIMS in this script.")
        return 1
    if problems:
        print(f"{len(problems)} stale claim(s) in store-listing.md — update the copy before submitting.")
        return 1
    print(f"All {checked} numeric claim(s) in store-listing.md match the bundled library.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
