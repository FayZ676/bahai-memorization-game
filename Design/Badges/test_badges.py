"""Asserts every invalid badge config is rejected.

Usage:  python3 Design/Badges/test_badges.py
"""

import copy
import json
import pathlib
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from badges import load_config, save_config, BadgeConfigError

GOOD = json.loads((HERE / "badges.json").read_text())
SCRATCH = pathlib.Path(tempfile.mkdtemp(prefix="badges-test-"))
BROKEN = SCRATCH / "broken.json"


def mutate(fn):
    cfg = copy.deepcopy(GOOD)
    fn(cfg)
    BROKEN.write_text(json.dumps(cfg))
    return cfg


def expect_rejected(name, fn):
    mutate(fn)
    try:
        load_config(BROKEN)
        print(f"  FAIL  {name}: ACCEPTED an invalid config")
        return False
    except BadgeConfigError as error:
        detail = [l.strip(" -") for l in str(error).splitlines()[1:]]
        print(f"  ok    {name}: {detail[0] if detail else error}")
        return True


cases = [
    ("protected icon override",
     lambda c: c["categories"]["healing"]["levels"]["2"].update(
         {"overrides": {"icon": "x"}})),
    ("protected shape override",
     lambda c: c["categories"]["healing"]["levels"]["2"].update(
         {"overrides": {"shape": "x"}})),
    ("unknown override field",
     lambda c: c["categories"]["healing"]["levels"]["2"].update(
         {"overrides": {"glow": "x"}})),
    ("unknown level key",
     lambda c: c["categories"]["healing"]["levels"]["2"].update({"bogus": 1})),
    ("unknown category key",
     lambda c: c["categories"]["healing"].update({"bogus": 1})),
    ("leveled category with own border",
     lambda c: c["categories"]["healing"].update({"border": "gold"})),
    ("binary category without border",
     lambda c: c["categories"]["first_prayer_memorized"].pop("border")),
    ("level missing from registry",
     lambda c: c["categories"]["healing"]["levels"].update({"7": {"label": "Ghost"}})),
    ("level missing label",
     lambda c: c["categories"]["healing"]["levels"]["2"].pop("label")),
    ("category missing icon",
     lambda c: c["categories"]["healing"].pop("icon")),
    ("registry level missing border",
     lambda c: c["levels"]["2"].pop("border")),
    ("global missing detail_level",
     lambda c: c["global"].pop("detail_level")),
    ("wrong schema_version",
     lambda c: c.update({"schema_version": 99})),
    ("non-numeric level key",
     lambda c: c["categories"]["healing"]["levels"].update({"two": {"label": "X"}})),
]

print("=== invalid configs must be rejected on load ===")
results = [expect_rejected(name, fn) for name, fn in cases]

print()
print("=== save_config must refuse to persist an invalid config ===")
target = SCRATCH / "savetest.json"
target.write_text((HERE / "badges.json").read_text())
before = target.read_text()
cfg = load_config(target)
cfg["categories"]["healing"]["levels"][2]["overrides"] = {"icon": "sneaky"}
try:
    save_config(cfg, target)
    print("  FAIL: persisted an invalid config")
    results.append(False)
except BadgeConfigError:
    unchanged = target.read_text() == before
    print(f"  ok    refused to write; file untouched: {unchanged}")
    results.append(unchanged)

print()
print(f"{sum(results)}/{len(results)} passed")
sys.exit(0 if all(results) else 1)
