import json, subprocess, sys, time, os

UDID = os.environ.get("SIM_UDID", "1E8D6700-3D51-4887-9A14-92E48D59B4B7")
OUT = os.environ.get("SHOT_DIR", os.getcwd())


def ui():
    r = subprocess.run(["idb", "ui", "describe-all", "--udid", UDID],
                       capture_output=True, text=True, check=True)
    return json.loads(r.stdout)


_screen = None


def screen(tree=None):
    """Screen size in points, taken from the Application element."""
    global _screen
    if _screen is None:
        for e in (tree if tree is not None else ui()):
            if e.get("type") == "Application":
                f = e["frame"]
                _screen = (f["width"], f["height"])
                break
        else:
            _screen = (440, 956)
    return _screen


def onscreen(e):
    w, h = screen()
    f = e["frame"]
    cy = f["y"] + f["height"] / 2
    cx = f["x"] + f["width"] / 2
    return 0 <= cy <= h and 0 <= cx <= w


def find(sub, kind=None, nth=0, require_onscreen=True):
    hits = []
    for e in ui():
        lbl = e.get("AXLabel") or ""
        uid = e.get("AXUniqueId") or ""
        if sub.lower() in lbl.lower() or sub.lower() == uid.lower():
            if kind is None or e.get("type") == kind:
                if not require_onscreen or onscreen(e):
                    hits.append(e)
    if not hits:
        raise SystemExit(f"no {'on-screen ' if require_onscreen else ''}element matching {sub!r}")
    return hits[nth]


def center(e):
    f = e["frame"]
    return f["x"] + f["width"] / 2, f["y"] + f["height"] / 2


def tap(sub, kind=None, nth=0, pause=1.4):
    e = find(sub, kind, nth)
    x, y = center(e)
    subprocess.run(["idb", "ui", "tap", "--udid", UDID, str(round(x)), str(round(y))], check=True)
    time.sleep(pause)
    return e


def tap_xy(x, y, pause=1.4):
    subprocess.run(["idb", "ui", "tap", "--udid", UDID, str(round(x)), str(round(y))], check=True)
    time.sleep(pause)


def swipe(x1, y1, x2, y2, pause=1.2, duration=0.25):
    subprocess.run(["idb", "ui", "swipe", "--udid", UDID, "--duration", str(duration),
                    str(round(x1)), str(round(y1)), str(round(x2)), str(round(y2))], check=True)
    time.sleep(pause)


def shot(name):
    p = os.path.join(OUT, name)
    subprocess.run(["xcrun", "simctl", "io", UDID, "screenshot", p],
                   capture_output=True, check=True)
    print("shot:", name)
    return p


def dump(label=""):
    print(f"--- ui {label} ---")
    for e in ui():
        f = e["frame"]
        print(f"  {e.get('type','?'):12s} ({round(f['x']):3d},{round(f['y']):3d} "
              f"{round(f['width']):3d}x{round(f['height']):3d}) "
              f"{(e.get('AXLabel') or e.get('AXUniqueId') or '')[:70]!r}")


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "dump":
        dump()
    elif cmd == "tap":
        tap(sys.argv[2])
        dump("after tap")
    elif cmd == "shot":
        shot(sys.argv[2])
