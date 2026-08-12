import argparse
import json
import re
import subprocess
import sys
import unicodedata
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent.parent
RUHI_PATH = HERE / "ruhi.json"
CACHE = HERE / "cache"

BAHA = "Bahá’u’lláh"
ABDU = "‘Abdu’l-Bahá"
BAB = "The Báb"
SHOGHI = "Shoghi Effendi"

BOOKS = {
    1: {
        "title": "Reflections on the Life of the Spirit",
        "units": ["Understanding the Bahá’í Writings", "Prayer", "Life and Death"],
    },
    2: {
        "title": "Arising to Serve",
        "url": "https://www.ruhi.org/full_texts/RUHI0060_AS_BK2_EN_2.1.1.PE_FullText_20200930.pdf",
        "units": ["The Joy of Teaching", "Uplifting Conversations", "Deepening Themes"],
        "headings": {"The Joy of Teaching": 0, "Uplifting Conversations": 1, "Deepening Themes": 2},
    },
    3: {
        "title": "Teaching Children’s Classes, Grade 1",
        "url": "https://www.ruhi.org/full_texts/RUHI0110_CC1_BK3_EN_2.2.1.PE_FullText_20210930.pdf",
        "units": ["Some Principles of Bahá’í Education", "Lessons for Children’s Classes, Grade 1"],
        "headings": {"Bahá’í Education": 0, "Grade 1": 1},
    },
    4: {
        "title": "The Twin Manifestations",
        "url": "https://www.ruhi.org/full_texts/RUHI0210_TWM_BK4_EN_2.1.1.PE_FullText_20211217.pdf",
        "units": ["The Greatness of This Day", "The Life of the Báb", "The Life of Bahá’u’lláh"],
        "headings": {"This Day": 0, "The Life of the Báb": 1, "The Life of Bahá’u’lláh": 2},
    },
    5: {
        "title": "Releasing the Powers of Junior Youth",
        "url": "https://www.ruhi.org/full_texts/RUHI0260_JY1_BK5_EN_2.1.1.PE_FullText_20220712.pdf",
        "units": ["Life’s Springtime", "An Age of Promise", "Serving as an Animator"],
        "headings": {"Life’s Springtime": 0, "An Age of Promise": 1, "Serving as an Animator": 2},
    },
    6: {
        "title": "Teaching the Cause",
        "url": "https://www.ruhi.org/full_texts/RUHI0310_TCH_BK6_EN_2.1.1.PE_FullText_20230420.pdf",
        "units": [
            "The Spiritual Nature of Teaching",
            "Qualities and Attitudes Essential for Teaching",
            "The Act of Teaching",
        ],
        "headings": {"of Teaching": 0, "Essential for Teaching": 1, "The Act of Teaching": 2},
    },
    7: {
        "title": "Walking Together on a Path of Service",
        "url": "https://www.ruhi.org/full_texts/RUHI0360_WLK_BK7_EN_2.1.1.PE_FullText_20240225.pdf",
        "units": [
            "The Spiritual Dynamics of Advancing on a Path of Service",
            "Serving as a Tutor of the Institute Courses",
            "Promoting the Arts at the Grassroots",
        ],
        "headings": {"on a Path of Service": 0, "of the Institute Courses": 1, "at the Grassroots": 2},
    },
}

WORKS_BY_AUTHOR = [
    (BAHA, [
        "The Hidden Words", "Gleanings from the Writings of Bahá’u’lláh", "Kitáb-i-Íqán",
        "Kitáb-i-Aqdas", "Epistle to the Son of the Wolf", "Tablets of Bahá’u’lláh Revealed after",
        "The Call of the Divine Beloved", "The Summons of the Lord of Hosts", "Prayers and Meditations",
        "Days of Remembrance", "The Seven Valleys", "The Tabernacle of Unity", "From a Tablet of Bahá’u’lláh",
    ]),
    (ABDU, [
        "Selections from the Writings of ‘Abdu’l-Bahá", "Paris Talks", "The Promulgation of Universal Peace",
        "Some Answered Questions", "The Secret of Divine Civilization", "Will and Testament of ‘Abdu’l-Bahá",
        "Tablets of the Divine Plan", "Tablets of Abdul-Baha", "Abdul Baha on Divine Philosophy",
        "Memorials of the Faithful", "Light of the World", "From a Tablet of ‘Abdu’l-Bahá",
        "From a Tablet of ‘Abdu’l‐Bahá",
    ]),
    (BAB, ["Selections from the Writings of the Báb"]),
    (SHOGHI, ["This Decisive Hour", "Bahá’í Administration", "written by Shoghi Effendi"]),
]

ATTRIBUTED = re.compile(r"^(Bahá’u’lláh|‘Abdu’l-Bahá|The Báb|Shoghi Effendi)\b")
TALK = re.compile(r"From a talk given (by ‘Abdu’l-Bahá )?on")

MEMORIZE = re.compile(r"memoriz|commit(?:ted)? to memory|learn(?:ed)? by heart", re.I)
DIRECTION = re.compile(
    r"following|below|above|these|this quotation|this prayer|in this section|from the sets|as many as you are able",
    re.I,
)
IMPERATIVE = re.compile(r"^\s*(\d+\.\s*)?(Now )?Memoriz(e|ation)\b", re.I)
SINGULAR = re.compile(
    r"\b(the above|this) (passage|quotation|prayer)\b"
    r"|\b(the|a) (following|below) (passage|quotation|prayer)\b"
    r"|\bthe (passage|quotation|prayer) below\b|\bthe one below\b"
    r"|\bmemorize the following quotation\b|\bmemorize the prayer below\b",
    re.I,
)
BACKWARD = re.compile(r"\babove\b|\bthese short passages\b|\bpreceding\b|from the sets above|in this section", re.I)
STORY = re.compile(r"^\s*[−-]\s*(Participant|A:|Q:)|Anna|\bI have observed\b|\bhe says\b|\bshe says\b", re.I)

UNATTRIBUTED = {
    (3, "O Son of Spirit! My first counsel is this"): (BAHA, "The Hidden Words, Arabic no. 1"),
    (5, "The incomparable Creator hath created"): (BAHA, "Gleanings from the Writings of Bahá’u’lláh"),
    (5, "O my God! O my God! Thou seest me in my lowliness"): (ABDU, "Tablets of the Divine Plan"),
    (5, "He is the Compassionate, the All-Bountiful"): (ABDU, "Bahá’í Prayers"),
    (5, "Protect yourselves with utmost vigilance"): (ABDU, "Selections from the Writings of ‘Abdu’l-Bahá"),
    (5, "My first counsel is this: Possess a pure"): (BAHA, "The Hidden Words, Arabic no. 1"),
    (5, "First in a human being’s way of life"): (ABDU, "Selections from the Writings of ‘Abdu’l-Bahá"),
}

STORY_DIALOGUE = (
    "Oh! If only ‘Abdu’l-Bahá would take my heart",
    "My dear, all your plans will come to naught",
)

JOINED_WORDS = {"fellow- ship": "fellowship"}


def fetch(book, refresh):
    CACHE.mkdir(exist_ok=True)
    pdf = CACHE / f"book{book}.pdf"
    text = CACHE / f"book{book}.txt"
    if text.exists() and not refresh:
        return unicodedata.normalize("NFC", text.read_text(encoding="utf-8")).split("\n")
    if not pdf.exists() or refresh:
        url = BOOKS[book]["url"]
        print(f"downloading book {book}")
        with urllib.request.urlopen(url) as response:
            pdf.write_bytes(response.read())
    subprocess.run(["pdftotext", "-layout", str(pdf), str(text)], check=True)
    return unicodedata.normalize("NFC", text.read_text(encoding="utf-8")).split("\n")


def strip_running_heads(lines):
    kept = []
    for line in lines:
        stripped = line.rstrip()
        looks_like_folio = re.match(r"^\s*\d+\s*[–-]\s*\w", stripped) or re.match(r"^\s*\S.*\s[–-]\s\d+\s*$", stripped)
        kept.append("" if looks_like_folio and len(stripped.strip()) < 60 else stripped)
    return kept


def tidy(text):
    text = re.sub(r"\s+", " ", text).strip()
    text = re.sub(r"(?<=[a-z’”.,;:!?])\s?(\d{1,2})(?=\s|$)", "", text)
    for broken, whole in JOINED_WORDS.items():
        text = text.replace(broken, whole)
    text = re.sub(r"(\w)- (\w)", r"\1-\2", text)
    text = re.sub(r"\.\s\.\s\.\s\.", ". …", text)
    text = re.sub(r"\.\s\.\s\.", "…", text)
    text = re.sub(r"^…\s+", "…", text)
    text = re.sub(r"\s+…$", "…", text)
    return re.sub(r"\s+", " ", text).strip()


def read_quotations(lines):
    quotations = []
    buffer = None
    start = 0
    for index, line in enumerate(lines):
        stripped = line.strip()
        if buffer is None:
            if "“" not in stripped:
                continue
            start = index
            buffer = stripped[stripped.index("“"):]
        else:
            if not stripped and "”" not in buffer:
                continue
            buffer += " " + stripped
        if "”" in buffer:
            close = buffer.index("”")
            trailing = buffer[close + 1:].strip()
            note = re.match(r"^(\d+)", trailing)
            quotations.append({
                "line": start,
                "text": tidy(buffer[1:close]),
                "note": int(note.group(1)) if note else None,
            })
            buffer = None
    return quotations


def short_label(citation):
    label = re.sub(r"^(Bahá’u’lláh|‘Abdu’l-Bahá|The Báb|Shoghi Effendi),\s*(cited by [^,]+,\s*)?(in\s+)?", "", citation)
    label = re.sub(r"^From a talk given[^,]*,\s*published in\s+", "", label)
    label = label.split(" (")[0].split(":")[0]
    label = re.split(r",\s(?=[a-z0-9]|no\.|par\.|pp?\.|[IVXLC]+,)", label)[0]
    return label.rstrip(" .,")


def read_references(lines):
    blocks = {}
    for anchor in [i for i, line in enumerate(lines) if line.strip().upper() == "REFERENCES"]:
        table = {}
        current = None
        parts = []
        cursor = anchor + 1
        while cursor < len(lines) and cursor - anchor <= 500:
            stripped = lines[cursor].strip()
            numbered = re.match(r"^(\d{1,3})\.\s+(.*)", stripped)
            if numbered:
                value = int(numbered.group(1))
                expected = 1 if current is None else current + 1
                if value == expected:
                    if current is not None:
                        table[current] = re.sub(r"\s+", " ", " ".join(parts)).strip()
                    current, parts = value, [numbered.group(2)]
                    cursor += 1
                    continue
                if current is not None:
                    break
            if current is not None and stripped:
                parts.append(stripped)
            cursor += 1
        if current is not None:
            table[current] = re.sub(r"\s+", " ", " ".join(parts)).strip()
        blocks[anchor] = resolve_citations(table)
    return blocks


def resolve_citations(table):
    resolved = {}
    label = ""
    author = ""
    for number in sorted(table):
        citation = table[number]
        if re.match(r"^ibid\.?", citation, re.I) and label:
            citation = re.sub(r"^ibid\.?", label, citation, flags=re.I)
        else:
            label = short_label(citation) or label
            named = ATTRIBUTED.match(citation)
            author = named.group(1) if named else ""
        resolved[number] = {"citation": citation, "author": author}
    return resolved


def attribute(citation, inherited):
    named = ATTRIBUTED.match(citation)
    if named and named.group(1) != SHOGHI:
        return named.group(1)
    for author, works in WORKS_BY_AUTHOR:
        if any(work in citation for work in works):
            return author
    if TALK.search(citation):
        return ABDU
    return named.group(1) if named else inherited


def label_for(citation):
    if "The Hidden Words" in citation:
        numbered = re.search(r"(Arabic|Persian)\s+no\.\s*(\d+)", citation)
        return f"The Hidden Words, {numbered.group(1)} no. {numbered.group(2)}" if numbered else "The Hidden Words"
    return short_label(citation)


def worth_memorizing(text):
    return len(text.split()) >= 6 and re.search(r"[.!?…]”?\s*$", text)


def locate(lines):
    units = []
    for index, line in enumerate(lines):
        if line.strip() != "Purpose":
            continue
        for back in range(index - 1, max(0, index - 6), -1):
            candidate = lines[back].strip()
            if candidate and not candidate.isdigit():
                units.append((back, candidate))
                break
    divisions = [
        (i, f"{m.group(1).title()} {m.group(2)}")
        for i, line in enumerate(lines)
        if (m := re.match(r"^(SECTION|LESSON)\s+(\d+)$", line.strip()))
    ]
    return units, divisions


def gather(book, refresh):
    lines = strip_running_heads(fetch(book, refresh))
    quotations = read_quotations(lines)
    references = read_references(lines)
    anchors = sorted(references)
    units, divisions = locate(lines)

    for quotation in quotations:
        anchor = next((a for a in anchors if a > quotation["line"]), None)
        entry = references.get(anchor, {}).get(quotation["note"]) if quotation["note"] else None
        quotation["citation"] = entry["citation"] if entry else ""
        quotation["inherited"] = entry["author"] if entry else ""
        quotation["unit"] = next((t for i, t in reversed(units) if i < quotation["line"]), "")
        quotation["division"] = next((t for i, t in reversed(divisions) if i < quotation["line"]), "")

    context = [" ".join(l.strip() for l in lines[i:i + 3]) for i in range(len(lines))]
    prompts = []
    for index, line in enumerate(lines):
        if not MEMORIZE.search(line) or STORY.search(context[index]):
            continue
        if IMPERATIVE.match(line) or DIRECTION.search(context[index]):
            prompts.append(index)
    prompts = [p for i, p in enumerate(prompts) if i == 0 or p - prompts[i - 1] > 2]

    edges = sorted({i for i, _ in divisions})
    selected = []
    for prompt in prompts:
        window = context[prompt]
        one_only = SINGULAR.search(window)
        if BACKWARD.search(window):
            low = max([e for e in edges if e < prompt], default=0)
            picked = [q for q in quotations if low <= q["line"] <= prompt and worth_memorizing(q["text"])]
            picked = picked[-1:] if one_only and picked else picked
        else:
            high = min([e for e in edges if e > prompt], default=len(lines))
            picked = []
            cursor = prompt
            for quotation in quotations:
                if not prompt <= quotation["line"] <= high or not worth_memorizing(quotation["text"]):
                    continue
                if quotation["line"] - cursor > 14:
                    break
                picked.append(quotation)
                cursor = quotation["line"] + quotation["text"].count(" ") // 12
            picked = picked[:1] if one_only and picked else picked
        selected.extend(picked)
    return selected


def entries_for(book, refresh):
    spec = BOOKS[book]
    entries = []
    seen = set()
    for quotation in gather(book, refresh):
        text = quotation["text"]
        if quotation["line"] in seen or text in seen:
            continue
        seen.update({quotation["line"], text})
        if any(text.startswith(opening) for opening in STORY_DIALOGUE):
            continue
        citation = quotation["citation"]
        author = attribute(citation, quotation["inherited"]) if citation else ""
        label = label_for(citation) if citation else ""
        for (target, opening), (fixed_author, fixed_label) in UNATTRIBUTED.items():
            if target == book and text.startswith(opening):
                author, label = fixed_author, fixed_label
        index = spec["headings"].get(quotation["unit"])
        if index is None or not author or not label:
            raise SystemExit(f"book {book}: unresolved quotation at line {quotation['line']}: {text[:60]}")
        entries.append({
            "author": author,
            "heading": "",
            "text": text,
            "tags": ["Ruhi", f"Book {book}", f"Unit {index + 1}", quotation["division"], label],
            "primaryTag": f"Unit {index + 1}: {spec['units'][index]}",
            "collection": "Ruhi",
            "section": f"Book {book}: {spec['title']}",
        })
    return entries


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--refresh", action="store_true", help="re-download the full texts")
    parser.add_argument("--dry-run", action="store_true", help="print the tree, write nothing")
    args = parser.parse_args()

    existing = json.loads(RUHI_PATH.read_text(encoding="utf-8")) if RUHI_PATH.exists() else []
    entries = [entry for entry in existing if entry["section"].startswith("Book 1:")]
    if not entries:
        raise SystemExit("ruhi.json is missing Book 1, which has no machine-readable source")

    for book in [2, 3, 4, 5, 6, 7]:
        book_entries = entries_for(book, args.refresh)
        print(f"book {book}: {len(book_entries)} quotations")
        entries.extend(book_entries)

    section = division = None
    for entry in entries:
        if entry["section"] != section:
            section, division = entry["section"], None
            print(f"\n{entry['section']}")
        if entry["primaryTag"] != division:
            division = entry["primaryTag"]
            print(f"  {division}")
        print(f"    {entry['text'][:76]}")

    print(f"\n{len(entries)} quotations")
    if args.dry_run:
        return 0

    RUHI_PATH.write_text(json.dumps(entries, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {RUHI_PATH.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
