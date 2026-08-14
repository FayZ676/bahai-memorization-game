# App Store screenshots

Captured from simulators at exactly the sizes App Store Connect requires.

The `-framed/` folders hold what actually gets uploaded: the same shots composed with a
headline and a phone bezel by `Design/StoreFrames/`. The bare folders are the source
those are built from — reshoot here, then regenerate the tiles.

| Folder | Device | Pixels | Required because |
|---|---|---|---|
| `iphone-6.9/` | iPhone 17 Pro Max (iOS 26) | 1320 × 2868 | the mandatory iPhone size |
| `ipad-13/` | iPad Pro 13-inch M4 (iOS 26) | 2064 × 2752 | `TARGETED_DEVICE_FAMILY = "1,2"` ships an iPad build |

Both simulators must be on the **iOS 26** runtime — the app's deployment target refuses
to install on the 18.6 iPad Pro that carries the same name.

These are the raw captures. What gets uploaded is the five tiles in `-framed/`, which
read in order as one pass through the app — see `Design/StoreFrames/README.md`.

| Raw capture | Becomes | Shows |
|---|---|---|
| `3-built-in-library.png` | `1-choose.png` | the Writings surface: search, My Writings, bundled collections with counts |
| `2-hide-words.png` | `2-hide.png` | the hero prayer's second section, 24% hidden |
| `9-hide-more.png` | `3-hide-more.png` | the *same* section at 33%, which is what makes the set a sequence rather than a gallery |
| `recite-aloud.png` | `4-recite.png` | the session listening, mic active, words marking as they are spoken |
| `6-library-dark.png` | `5-know.png` | the library in dark, streak and progress ramps, several passages finished |

Every raw here feeds a tile; there are no spares left. The iPad has no dark capture, so its
`5-know.png` falls back to `ipad-13/1-library.png` through the tile's `per_device`
override. There is no iPad recitation tile — the raw was never shot there, so it is skipped
the same way the later session stage already is.

Two captures are stage-dependent and must be reshot as a pair if the hero passage changes:
`2-hide-words.png` from the default seed and `9-hide-more.png` from `HERO_LATE=1`, which
hides 85% of the same chunk instead of 40%. `HERO_LATE` deliberately leaves the later
chunks empty so the session still lands on section 2 in both, keeping the two tiles
identical but for the blanks.

The dark tile is shot with `python3 tools/seed.py dark` and the simulator in dark
appearance, from the same picks as the light library, so the streak and the progress ramps
read identically in both.

If you drop the iPad build (`TARGETED_DEVICE_FAMILY = 1`), `ipad-13/` is no longer needed.

## Staging the recitation shot

`recite-aloud.png` is the one capture the simulator cannot reach on its own. Speech
recognition never enters its listening state there — no on-device speech model and no audio
input — so the mic falls straight back to idle and there is nothing to photograph.

`SHOT_RECITING=1` puts the session into that state without speaking: it marks the first half
of the section's hidden words as recited, parks the cursor on the next one, and fills the
heard line with the words leading up to it. The UI is the same one a real device draws; only
the trigger is staged, the way `seed.py` stages persisted state. It is `#if DEBUG` in
`SessionView` and `VoiceRecitationController`, so it cannot reach a release build.

It must be passed through to the app, not to `simctl` itself:

```sh
SIMCTL_CHILD_SHOT_RECITING=1 xcrun simctl launch "$SIM_UDID" com.faizififita.MemorizationGame
```

The staging runs **three seconds after** the session appears, and that delay is load-bearing:
`vm.start()` bumps `presentationEpoch`, whose `onChange` calls `voice.stop()` and
`highlights.clear()`. Anything staged before that fires is wiped, which looks exactly like
the flag not working. Wait ~9s after tapping in before shooting.

Shooting it on a physical iPhone instead is still valid, and needs no flag — but the screen
has to be 1320 × 2868 (a 16/17 Pro Max), since App Store Connect rejects other sizes rather
than scaling them.

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

`ACHIEVEMENTS=1` appends four more passages that only an achievements shot needs — a
second earned badge and three rings part-way round, so the screen is not a column of
untouched dashes. No uploaded tile draws on it since the set narrowed to four, so leave it
unset unless you are shooting that screen again; it adds rows to the library.

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
