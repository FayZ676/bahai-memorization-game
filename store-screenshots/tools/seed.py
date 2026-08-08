import json, uuid, sys, datetime, subprocess, os, random

REPO = "/Users/faizififita/workspace/memorization-game"
DEV = os.environ.get("SIM_UDID", "1E8D6700-3D51-4887-9A14-92E48D59B4B7")
BUNDLE = "com.faizififita.MemorizationGame"
HERO_GROUP = int(os.environ.get("HERO_GROUP", "2"))

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
    """Mirrors Reviewable.tokens: split on space/newline, then split internal hyphens."""
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
    """Descending fill across n chunks: `solid` fully-hidden, then a smooth fall to lo."""
    vals = [1.0] * solid
    rest = n - solid
    if rest > 0:
        for i in range(rest):
            t = i / max(rest - 1, 1)
            vals.append(hi + (lo - hi) * t)
    return vals[:n]


# (needle, section, lines-per-chunk, per-chunk fill fractions)
PICKS = [
    # session hero: lands on the 40%-hidden chunk; HERO_GROUP=4 fills the wider iPad page
    ("I have turned in repentance unto Thee", None,  HERO_GROUP, [1.0, 0.4, 0.0, 0.0]),
    # library hero: 9 short chunks, a clean descending ramp
    ("Prayer for the Dead", "General Prayers",       1, ramp(9, hi=0.95, lo=0.0, solid=3)),
    ("I bear witness, O my God", "Obligatory Prayers", 1, [1.0, 1.0]),
    ("Blessed is the spot", None,                    1, [1.0]),
    ("Is there any Remover", None,                   1, [1.0]),
    ("My first counsel is this", "From the Arabic",  1, [0.45]),
]

# extra passages that only the achievements shot needs: one more earned badge and
# two rings part-way round, so the screen is not a column of untouched dashes
ACHIEVEMENT_PICKS = [
    ("Thy name is my healing", "General Prayers",   1, [1.0]),
    ("I have wakened in Thy shelter", "General Prayers", 1, [0.55]),
    ("I have detached myself from my kindred", "General Prayers", 1, [0.2]),
    ("Love Me, that I may love thee", "From the Arabic", 1, [1.0, 1.0]),
]

if os.environ.get("ACHIEVEMENTS"):
    PICKS += ACHIEVEMENT_PICKS

passages, reviewables = [], []
now = datetime.datetime.now(datetime.timezone.utc)
REF = datetime.datetime(2001, 1, 1, tzinfo=datetime.timezone.utc)

for n, (needle, sec, group, fills) in enumerate(PICKS):
    e = find(needle, sec)
    pid = str(uuid.uuid4()).upper()
    added = now - datetime.timedelta(days=(len(PICKS) - n) * 3)
    passages.append({
        "id": pid,
        "title": title_of(e),
        "dateAdded": (added - REF).total_seconds(),
        "author": e.get("author"),
        "section": e.get("section"),
        "sourceID": e["id"],
    })
    units = units_of(e, group)
    for i, unit in enumerate(units):
        toks = tokens(unit)
        wc = len(toks)
        frac = fills[i] if i < len(fills) else 0.0
        k = int(round(wc * frac))
        if k >= wc:
            hidden = list(range(wc))
        elif k <= 0:
            hidden = []
        else:
            # scatter the hidden words the way real practice does, skipping bare
            # punctuation tokens so blanks always stand in for actual words
            wordish = [j for j, t in enumerate(toks) if any(c.isalpha() for c in t)]
            rng = random.Random(f"{needle}:{i}")
            hidden = sorted(rng.sample(wordish, min(k, len(wordish))))
        reviewables.append({
            "id": str(uuid.uuid4()).upper(),
            "passageRef": pid,
            "span": {"start": i + 1, "end": i + 1},
            "expectedText": unit,
            "hiddenWords": hidden,
        })

# practice log: an unbroken streak ending today, with a visible ramp-up before it
words_by_day = {}
today = datetime.date.today()
STREAK = 14
recent = [29, 24, 33, 26, 41, 24, 27, 38, 24, 31, 45, 24, 28, 35]
for back in range(STREAK):
    words_by_day[(today - datetime.timedelta(days=back)).strftime("%Y-%m-%d")] = recent[back]
earlier = {15: 12, 16: 19, 18: 9, 19: 22, 21: 15, 22: 8, 24: 17}
for back, w in earlier.items():
    words_by_day[(today - datetime.timedelta(days=back)).strftime("%Y-%m-%d")] = w

SAVED = [
    ("Blessed is the spot", None),
    ("Thy heart is My home", None),
    ("Tablet of A", "Special Tablets"),
]

saved_writings = []
for n, (needle, sec) in enumerate(SAVED):
    e = find(needle, sec)
    saved_writings.append({
        "id": str(uuid.uuid4()).upper(),
        "prayerID": e["id"],
        "title": title_of(e),
        "text": e["text"],
        "author": e.get("author"),
        "section": e.get("section"),
        "savedAt": ((now - datetime.timedelta(days=n * 2 + 1)) - REF).total_seconds(),
    })

recent_prayer_ids = [find(needle, sec)["id"] for needle, sec in [
    ("Is there any Remover", None),
    ("I have turned in repentance unto Thee", None),
    ("Prayer for the Dead", "General Prayers"),
    ("Blessed is the spot", None),
]]

snapshot = {
    "passages": passages,
    "reviewables": reviewables,
    "practiceLog": {"wordsByDay": words_by_day},
    "savedWritings": saved_writings,
    "recentPrayerIDs": recent_prayer_ids,
    "settings": {
        "reminderEnabled": False,
        "reminders": [{"id": str(uuid.uuid4()).upper(), "minuteOfDay": 540,
                       "message": "A few minutes with your passages keeps them fresh."}],
        "streakReminderEnabled": True,
        "appTheme": sys.argv[1] if len(sys.argv) > 1 else "light",
        "fontSize": "medium",
        "hasSeenWelcomeTour": True,
    },
}

container = subprocess.run(
    ["xcrun", "simctl", "get_app_container", DEV, BUNDLE, "data"],
    capture_output=True, text=True, check=True).stdout.strip()
path = os.path.join(container, "Documents", "store.json")
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    json.dump(snapshot, f)

print("wrote", path)
print(f"passages: {len(passages)}  cards: {len(reviewables)}  streak: {STREAK}")
for p, _pick in zip(passages, PICKS):
    cards = [r for r in reviewables if r["passageRef"] == p["id"]]
    heats = [round(len(c["hiddenWords"]) / max(len(tokens(c["expectedText"])), 1), 2) for c in cards]
    print(f"  {p['title'][:44]:44s} {heats}")
