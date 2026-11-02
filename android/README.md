# Verses for Android

A native port of the iOS app: Kotlin and Jetpack Compose, with the same recitation engine.

```
android/
  logic/   plain Kotlin, no Android: the word model, tokenizer, aligner, tracker, session,
           library, achievements, search. Runs on the Mac's JVM, which is how the bench tests it.
  app/     Compose UI, microphone, ONNX Runtime, reminders, Play review prompt.
  store/   Play listing graphics and starter screenshots.
  scripts/ emulator.sh · bench.sh · bundle.sh
```

`logic/` is a line-for-line port of `MemorizationGame/Logic`. Change the two together.

## Try it on the Mac

```sh
android/scripts/emulator.sh
```

This boots a Pixel emulator, builds, installs, and opens Verses. The emulator uses the Mac's
microphone, so Recite works: say the prayer out loud. The first boot takes a minute; after that,
re-running the script just reinstalls the app.

The toolchain lives in Homebrew: `openjdk@17`, `android-commandlinetools` (SDK in
`/opt/homebrew/share/android-commandlinetools`), and `gradle`/`bundletool`. Android Studio is not
required, but if you install it and open `android/`, it picks the project up as is.

## Recitation is the same engine as iOS

`app/src/main/assets/conformer.onnx` is the same NVIDIA Conformer-CTC medium the iPhone uses,
exported to ONNX by `Tools/RecitationBench/candidates/onnx_convert.py` (weights stored as 16-bit,
computed in 32-bit; 63 MB). The bench is the contract here too:

```sh
android/scripts/bench.sh
```

replays every take in `Tools/RecitationBench/takes` through the Kotlin session and the ONNX model
on the Mac. On 2026-11-02 it credited exactly the words the Swift engine credits, flashed exactly
the same misses on all 25 takes, and credited no wrong word (1718/1724 correct, 0/103 wrong). The
same run on the Android emulator, through ONNX Runtime for Android, matched as well.

Debug builds have two test hooks that release builds do not:

- `BenchActivity` replays the takes on the device:
  `adb shell run-as com.faizififita.verses cp -r /data/local/tmp/takes files/` then
  `adb shell am start -n com.faizififita.verses/.BenchActivity`; results go to
  `files/bench-android.json`, timings to `adb logcat -s BENCH`.
- If `files/replay.raw` (16 kHz mono float32) exists, Recite plays it instead of the microphone.

`adb logcat -s RECITE` shows every recitation hop in a debug build.

## Shipping to testers

Package name `com.faizififita.verses` — permanent once uploaded.

1. **Signing.** `android/release.keystore` + `android/keystore.properties` hold the upload key. Both
   are git-ignored. Back them up somewhere safe (a password manager). Play App Signing keeps the
   real signing key at Google; if the upload key is ever lost, Play Console can reset it.
2. **Build.** `android/scripts/bundle.sh` runs the tests and writes
   `app/build/outputs/bundle/release/app-release.aab`. Bump `versionCode` (and `versionName`) in
   `app/build.gradle.kts` for every upload.
3. **Play Console → Create app.** Name *Verses*, app, free.
4. **Testing → Closed testing** (or *Internal testing* for a first quick round with up to 100
   people): create a track, add testers by email or a Google Group, upload the `.aab`, and share
   the opt-in link with them.
   New personal developer accounts must run a closed test with **at least 12 testers opted in for
   14 days** before Play allows a production release, so start the closed track early.
5. **Store listing.** Copy from `store/play-listing.md`; graphics are in `store/`
   (`play-icon-512.png`, `feature-graphic.png`, `screenshots/`). Screenshots need at least 2.
6. **App content.**
   - Privacy policy: `https://fayz676.github.io/bahai-memorization-game/privacy.html` (covers Android
     once `docs/privacy.html` is pushed).
   - Data safety: no data collected automatically. Collected only when the user sends feedback:
     *App activity → Other user-generated content* (the message), *Personal info → Email address*
     (optional), *App info and performance → Diagnostics* (app version, phone model, OS version).
     Not shared, encrypted in transit, used for *Developer communications* and *App functionality*.
     Audio is processed on the device and never leaves it, so microphone audio is not "collected".
   - Content rating questionnaire: reference / education, no objectionable content.
   - Target audience: all ages is fine; there are no ads.

## What is different from iOS

- Navigation is Android's: system back gesture and button, Material time picker for reminders.
- Daily reminders use inexact alarms (within ~10 minutes of the chosen time) so the app needs no
  exact-alarm permission. They are re-armed after a reboot.
- Haptics map to Android vibration primitives; phones without them fall back to simple ticks.
- The review prompt is Play's in-app review.
- What's New starts at Android 1.0.0 (`feature/releasenotes/ReleaseNotes.kt`).
