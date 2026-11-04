import json, uuid, sys, datetime, subprocess, os, random

REPO = "/Users/faizififita/workspace/memorization-game"
DEV = os.environ.get("SIM_UDID", "1E8D6700-3D51-4887-9A14-92E48D59B4B7")
BUNDLE = "com.faizififita.MemorizationGame"
HERO_GROUP = int(os.environ.get("HERO_GROUP", "3"))
RELEASE_VERSION = subprocess.run(
    ["python3", f"{REPO}/scripts/project_version.py", "--get", "marketing"],
    capture_output=True, text=True, check=True).stdout.strip()

entries = json.load(open(f"{REPO}/MemorizationGame/Resources/library.json"))["entries"]


def find(sub, sec=None):
    for e in entries:
        haystack = e["text"] + "\n" + (e.get("heading") or "")
        if sub.lower() in haystack.lower() and (sec is None or e.get("section") == sec):
            return e
    raise SystemExit("not found: " + sub)


def title_of(e):
    h = (e.get("heading") or "").strip()
    return h if h else e["text"].split("\n")[0].strip()


def units_of(e, group=1):
    lines = [u.strip() for u in e["text"].split("\n") if u.strip()]
    if group <= 1:
        return lines
    return [" ".join(lines[i:i + group]) for i in range(0, len(lines), group)]


def tokens(text):
    """Mirrors Passage.tokens: split on space/newline, then split internal hyphens."""
    out = []
    for w in text.replace("\n", " ").split(" "):
        if not w:
            continue
        pieces, start, i = [], 0, 0
        while True:
            j = w.find("-", i)
            if j == -1:
                break
            after = j + 1
            if j > start and after < len(w):
                pieces.append(w[start:j])
                start = j
            i = after
        pieces.append(w[start:])
        out.extend(p for p in pieces if p)
    return out


def ramp(n, hi=1.0, lo=0.0, solid=0):
    """Descending fill across n groups of lines: `solid` fully-hidden, then a smooth fall to lo."""
    vals = [1.0] * solid
    rest = n - solid
    if rest > 0:
        for i in range(rest):
            t = i / max(rest - 1, 1)
            vals.append(hi + (lo - hi) * t)
    return vals[:n]


# the session hero, at two stages of the same passage, so the store tiles can show
# one passage getting harder rather than two unrelated screens
HERO_FILLS = [0.9, 0.5, 0.0, 0.0] if os.environ.get("HERO_LATE") else [0.5, 0.15, 0.0, 0.0]
if os.environ.get("HERO_FILLS"):
    HERO_FILLS = [float(v) for v in os.environ["HERO_FILLS"].split(",")]

# (needle, section, lines per fill group, per-group fill fractions)
PICKS = [
    # session hero; HERO_GROUP=3 fills the wider iPad page
    ("I have turned in repentance unto Thee", None,  HERO_GROUP, HERO_FILLS),
    # library hero: 9 short paragraphs, a clean descending ramp
    ("Prayer for the Dead", "General Prayers",       1, ramp(9, hi=0.95, lo=0.0, solid=3)),
    ("I bear witness, O my God", "Obligatory Prayers", 1, [1.0, 1.0]),
    ("Blessed is the spot", None,                    1, [1.0]),
    ("Is there any Remover", None,                   1, [1.0]),
    ("My first counsel is this", "From the Arabic",  1, [0.45]),
]

if os.environ.get("LONG"):
    PICKS.append(("Lo, the Nightingale of Paradise", None, 3, ramp(8, hi=0.9, lo=0.0, solid=1)))

passages = []
now = datetime.datetime.now(datetime.timezone.utc)
REF = datetime.datetime(2001, 1, 1, tzinfo=datetime.timezone.utc)

for n, (needle, sec, group, fills) in enumerate(PICKS):
    e = find(needle, sec)
    pid = str(uuid.uuid4()).upper()
    added = now - datetime.timedelta(days=(len(PICKS) - n) * 3)
    units = units_of(e, group)
    hidden, offset = [], 0
    for i, unit in enumerate(units):
        toks = tokens(unit)
        wc = len(toks)
        frac = fills[i] if i < len(fills) else 0.0
        k = int(round(wc * frac))
        if k >= wc:
            chosen = list(range(wc))
        elif k <= 0:
            chosen = []
        else:
            # scatter the hidden words the way real practice does, skipping bare
            # punctuation tokens so blanks always stand in for actual words
            wordish = [j for j, t in enumerate(toks) if any(c.isalpha() for c in t)]
            rng = random.Random(f"{needle}:{i}")
            chosen = sorted(rng.sample(wordish, min(k, len(wordish))))
        hidden.extend(offset + j for j in chosen)
        offset += wc
    passages.append({
        "id": pid,
        "title": title_of(e),
        "dateAdded": (added - REF).total_seconds(),
        "author": e.get("author"),
        "section": e.get("section"),
        "sourceID": e["id"],
        "text": "\n".join(u.strip() for u in e["text"].split("\n") if u.strip()),
        "hiddenWords": hidden,
    })

snapshot = {
    "passages": passages,
    "settings": {
        "reminderEnabled": False,
        "reminders": [{"id": str(uuid.uuid4()).upper(), "minuteOfDay": 540,
                       "message": "A few minutes with your passages keeps them fresh."}],
        "appTheme": sys.argv[1] if len(sys.argv) > 1 else "light",
        "fontSize": "medium",
        "hasSeenWelcomeTour": True,
        "lastSeenReleaseNotesVersion": RELEASE_VERSION,
    },
}

container = subprocess.run(
    ["xcrun", "simctl", "get_app_container", DEV, BUNDLE, "data"],
    capture_output=True, text=True, check=True).stdout.strip()
path = os.path.join(container, "Documents", "verses.json")
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    json.dump(snapshot, f)

print("wrote", path)
print(f"passages: {len(passages)}")
for p in passages:
    total = len(tokens(p["text"]))
    print(f"  {p['title'][:44]:44s} {len(p['hiddenWords'])}/{total} hidden")
