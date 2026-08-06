#!/usr/bin/env python3
"""Rebuild MemorizationGame/Resources/library.json from bahai.org.

See README.md in this folder for the contract this script upholds.
"""

import argparse
import hashlib
import json
import re
import sys
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

NS = "{http://www.w3.org/1999/xhtml}"
REPO_ROOT = Path(__file__).resolve().parents[2]
LIBRARY_PATH = REPO_ROOT / "MemorizationGame/Resources/library.json"
CACHE_DIR = Path(__file__).resolve().parent

BAHAI_ORG = "https://www.bahai.org/library/authoritative-texts"
PRAYERS_URL = f"{BAHAI_ORG}/prayers/bahai-prayers/bahai-prayers.xhtml"
HIDDEN_WORDS_URL = f"{BAHAI_ORG}/bahaullah/hidden-words/hidden-words.xhtml"

PRAYERS = "Prayers"
HIDDEN_WORDS = "The Hidden Words"
OPENING = "Opening Words"
BAHAULLAH = "Bahá’u’lláh"
REVEALERS = {BAHAULLAH, "The Báb", "‘Abdu’l-Bahá", "‘Abdu’l‑Bahá"}


def classes(element):
    return set((element.get("class") or "").split())


def text_of(element):
    return re.sub(r"\s+", " ", "".join(element.itertext())).strip()


def clean_text(element):
    copy = ET.fromstring(ET.tostring(element, encoding="unicode"))
    for parent in copy.iter():
        for child in list(parent):
            if child.tag == NS + "sup" or "td" in classes(child):
                siblings = list(parent)
                index = siblings.index(child)
                tail = child.tail or ""
                if index == 0:
                    parent.text = (parent.text or "") + tail
                else:
                    siblings[index - 1].tail = (siblings[index - 1].tail or "") + tail
                parent.remove(child)
    return re.sub(r"\s+", " ", "".join(copy.itertext())).strip()


def fetch(url, name, refresh):
    cached = CACHE_DIR / name
    if cached.exists() and not refresh:
        return cached.read_text(encoding="utf-8")
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request) as response:
        raw = response.read().decode("utf-8")
    cached.write_text(raw, encoding="utf-8")
    return raw


def document(raw):
    return ET.fromstring(raw[raw.index("<html") :])


def anchor_ids(element):
    return [
        node.get("id")
        for node in element.iter(NS + "a")
        if "sf" in classes(node) and node.get("id")
    ]


def parse_contents(nav):
    entries = {}

    def target(links):
        for link in links:
            href = link.get("href", "")
            if href.startswith("#"):
                return text_of(link), href.lstrip("#")
        return None, None

    def walk(container, trail):
        for item in container.findall(NS + "li"):
            heading = item.find(NS + "h3")
            label, anchor = target(
                heading.iter(NS + "a") if heading is not None else item.findall(NS + "a")
            )
            path = trail + [label] if label else trail
            if anchor:
                entries[anchor] = path
            for nested in item.findall(NS + "ul"):
                walk(nested, path)

    for top in nav.findall(NS + "ul"):
        walk(top, [])
    return entries


def collect_prayers(root, contents, sections):
    prayers = []
    trail = []
    subtitle = None
    body = []

    def emit(author):
        nonlocal subtitle, body
        text = "\n\n".join(body)
        cited = text.startswith("“") and text.endswith("”")
        path = trail or [OPENING]
        wanted = text and not cited and path[0] in sections and author in REVEALERS
        if wanted:
            prayers.append(
                {
                    "subtitle": subtitle,
                    "text": text,
                    "author": author,
                    "path": path,
                }
            )
            subtitle = None
        body = []

    def visit(element):
        nonlocal trail, subtitle
        if element.tag == NS + "div" and element.find(NS + "h1") is not None:
            return
        if element.tag == NS + "a" and "sf" in classes(element):
            path = contents.get(element.get("id"))
            if path:
                trail = path
            return
        if element.tag != NS + "p":
            for child in element:
                visit(child)
            return

        style = classes(element)
        content = clean_text(element)
        if "ac" in style:
            emit(content.lstrip("—").strip())
            return
        if content:
            if {"c", "l", "ub"} <= style or any(
                anchor in contents for anchor in anchor_ids(element)
            ):
                pass
            elif "kf" in style:
                subtitle = content
            elif not (content.startswith("(") and content.endswith(")")):
                body.append(content)
        for child in element:
            visit(child)

    visit(root.find(NS + "body"))
    return prayers


def build_prayers(refresh):
    root = document(fetch(PRAYERS_URL, "bahai-prayers.xhtml", refresh))
    contents = parse_contents(root.find(f".//{NS}nav"))
    sections = {path[0] for path in contents.values() if len(path) > 1} | {OPENING}
    prayers = collect_prayers(root, contents, sections)

    counts = {}
    for prayer in prayers:
        counts[tuple(prayer["path"])] = counts.get(tuple(prayer["path"]), 0) + 1
    parents = {
        tuple(path[:depth]) for path in contents.values() for depth in range(1, len(path))
    }

    entries = []
    for prayer in prayers:
        path = prayer["path"]
        chain = path[1:]
        heading = ""
        if chain and counts[tuple(path)] == 1 and tuple(path) not in parents:
            heading = chain[-1]
        if heading and prayer["subtitle"]:
            heading = f"{heading} — {prayer['subtitle']}"

        entries.append(
            {
                "author": prayer["author"],
                "heading": heading,
                "text": prayer["text"],
                "tags": list(dict.fromkeys(chain or [path[0]])),
                "primaryTag": chain[0] if chain else path[0],
                "collection": PRAYERS,
                "section": path[0],
                "source": PRAYERS_URL,
            }
        )
    return entries


def build_hidden_words(refresh):
    root = document(fetch(HIDDEN_WORDS_URL, "hidden-words.xhtml", refresh))
    entries = []
    section = None
    number = None

    def visit(element):
        nonlocal section, number
        if element.tag == NS + "h3":
            section = text_of(element)
        elif element.tag == NS + "p":
            style = classes(element)
            if {"db", "if"} <= style:
                number = text_of(element).rstrip(". ")
            elif "dd" in style and number:
                invocation = next(
                    (text_of(s) for s in element if "kf" in classes(s)), None
                )
                lines = clean_text(element)
                if invocation and lines.startswith(invocation):
                    lines = lines[len(invocation) :].strip()
                entries.append(
                    {
                        "author": BAHAULLAH,
                        "heading": f"{number}. {invocation}" if invocation else number,
                        "text": f"{invocation}\n\n{lines}" if invocation else lines,
                        "tags": [section],
                        "primaryTag": section,
                        "collection": HIDDEN_WORDS,
                        "section": section,
                        "source": HIDDEN_WORDS_URL,
                    }
                )
                number = None
        for child in element:
            visit(child)

    visit(root.find(NS + "body"))
    return entries


def stable_id(entry):
    seed = f"{entry['collection']}\n{entry['text']}".encode("utf-8")
    return int.from_bytes(hashlib.sha1(seed).digest()[:4], "big")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--refresh", action="store_true", help="re-download the sources")
    parser.add_argument("--dry-run", action="store_true", help="print the tree, write nothing")
    args = parser.parse_args()

    existing = json.loads(LIBRARY_PATH.read_text(encoding="utf-8"))["entries"]
    carried = [
        {key: entry[key] for key in FIELDS if key in entry}
        for entry in existing
        if entry["collection"] not in {PRAYERS, HIDDEN_WORDS, "Writings"}
    ]

    entries = build_prayers(args.refresh) + build_hidden_words(args.refresh) + carried
    for entry in entries:
        entry["id"] = stable_id(entry)
    entries = [{key: entry.get(key) for key in FIELDS} for entry in entries]

    minted = {entry["id"] for entry in entries}
    if len(minted) != len(entries):
        raise SystemExit("id collision — two entries hash alike")

    collection = section = tag = None
    for entry in entries:
        if entry["collection"] != collection:
            collection, section, tag = entry["collection"], None, None
            print(f"\n{collection}")
        if entry["section"] != section:
            section, tag = entry["section"], None
            print(f"  {section}")
        if entry["primaryTag"] != tag:
            tag = entry["primaryTag"]
            print(f"    {' › '.join(entry['tags'])}")
        label = entry["heading"] or entry["text"].split("\n")[0]
        print(f"      [{entry['id']}] {label[:70]}")

    print(f"\n{len(entries)} entries")
    if args.dry_run:
        return 0

    LIBRARY_PATH.write_text(
        json.dumps({"entries": entries}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {LIBRARY_PATH.relative_to(REPO_ROOT)}")
    return 0


FIELDS = ["id", "author", "heading", "text", "tags", "primaryTag", "collection", "section", "source"]


if __name__ == "__main__":
    sys.exit(main())
