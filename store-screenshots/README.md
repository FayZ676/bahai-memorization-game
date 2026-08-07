# App Store screenshots

Captured from simulators at exactly the sizes App Store Connect requires.

| Folder | Device | Pixels | Required because |
|---|---|---|---|
| `iphone-6.9/` | iPhone 17 Pro Max (iOS 26) | 1320 × 2868 | the mandatory iPhone size |
| `ipad-13/` | iPad Pro 13-inch M4 (iOS 26) | 2064 × 2752 | `TARGETED_DEVICE_FAMILY = "1,2"` ships an iPad build |

Both simulators must be on the **iOS 26** runtime — the app's deployment target refuses
to install on the 18.6 iPad Pro that carries the same name.

Upload order matters — the first two are what people see in search results.

1. `1-library.png` — library with the streak and per-passage progress ramps
2. `2-hide-words.png` — a passage part-hidden, the core mechanic
3. `3-built-in-library.png` — the Writings surface: search, My Writings, the bundled collections with counts
4. `4-preview.png` — reading a Hidden Word before memorizing it
5. `5-dark.png` — the same passage in dark
6. `6-library-dark.png`, `7-hidden-words.png`, `8-achievements.png` — spares

If you drop the iPad build (`TARGETED_DEVICE_FAMILY = 1`), `ipad-13/` is no longer needed.

## Not captured

The **recitation** screen. Speech recognition never reaches its listening state in a
simulator — no on-device speech model and no audio input — so the microphone reverts to
idle and there is nothing to photograph. To include it, capture on a physical iPhone whose
screen is 1320 × 2868 (a 16/17 Pro Max); a smaller phone produces the wrong pixel size.

## Regenerating

`tools/seed.py` writes a `store.json` straight into the simulator's app container, using
real passages from `MemorizationGame/Resources/library.json`. It mirrors the app's own
import logic — units split on newlines, `span` = unit index, hidden words scattered across
word-ish tokens — so the app loads it as if the passages had been imported by hand. It
also seeds `savedWritings` and `recentPrayerIDs` so the Writings surface has counts to
show, and sets `hasSeenWelcomeTour` so the guided tour does not cover the first screen.

`PICKS` names passages by a substring of their text or heading. The library is rebuilt
from bahai.org from time to time and passages do disappear — if `seed.py` exits with
`not found:`, pick a replacement of a similar shape rather than forcing the old one back.

`HERO_GROUP` sets how many source lines make up one chunk of the session hero passage.
Leave it at the default `2` for iPhone; use `3` for iPad, where a smaller chunk floats in
the middle of a much larger page.

`tools/drive.py` taps through the UI using `idb`, locating elements by accessibility label
so taps don't depend on hardcoded coordinates. Run it from inside `tools/` — it is
imported as a module, not resolved by path.

```sh
export SIM_UDID=<simulator udid>          # xcrun simctl list devices available
export SHOT_DIR=$PWD                       # where screenshots land

xcodebuild -project MemorizationGame.xcodeproj -scheme MemorizationGame \
  -configuration Debug -destination "id=$SIM_UDID" build
xcrun simctl boot "$SIM_UDID"; xcrun simctl bootstatus "$SIM_UDID" -b
xcrun simctl install "$SIM_UDID" <path to built MemorizationGame.app>

xcrun simctl launch "$SIM_UDID" com.faizififita.MemorizationGame   # create the container
python3 tools/seed.py light                # or: dark
xcrun simctl status_bar "$SIM_UDID" override --time "9:41" \
  --wifiMode active --wifiBars 3 --batteryState discharging --batteryLevel 100
xcrun simctl ui "$SIM_UDID" appearance light
xcrun simctl terminate "$SIM_UDID" com.faizififita.MemorizationGame
xcrun simctl launch "$SIM_UDID" com.faizififita.MemorizationGame
```

Then drive it:

```python
import drive, time
drive.shot("1-library.png")
drive.tap("I have turned in repentance", pause=2)
time.sleep(6)                              # let the 1.4s grounding reveal finish
drive.shot("2-hide-words.png")
```

Things that will bite you:

- **Dismiss the notification prompt first.** A fresh install asks on launch;
  `drive.tap("Don’t Allow")` clears it.
- **Wait ~6s after entering a session.** It deliberately shows every word for 1.4s, then
  ripples them away. Screenshot too early and nothing looks hidden.
- **`idb connect <udid>` first**, and only tap elements that are on screen — `drive.find`
  filters to those, because tapping a list row scrolled out of view sends the tap to
  whatever is at that coordinate, which can background the app.
- **The iPad shots carry a small grey arc in the bottom-right corner** — iPadOS's Quick
  Note affordance. It survives disabling the corner gesture and a respring, and it is
  present in the 1.0 screenshots Apple approved, so it is left alone.
