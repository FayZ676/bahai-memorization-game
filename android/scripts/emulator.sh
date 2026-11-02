#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"

if ! emulator -list-avds | grep -qx "$AVD"; then
  echo no | "$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager" create avd -n "$AVD" \
    -k "system-images;android-35;google_apis;arm64-v8a" -d pixel_7 --force
  sed -i '' 's/^hw.audioInput=.*/hw.audioInput=yes/' ~/.android/avd/$AVD.avd/config.ini
fi

if ! adb devices | grep -q "emulator-"; then
  emulator -avd "$AVD" -allow-host-audio -no-snapshot-save >/dev/null 2>&1 &
  adb wait-for-device
  until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 2; done
fi

cd "$ANDROID_DIR"
./gradlew -q :app:assembleDebug
if ! adb install -r app/build/outputs/apk/debug/app-debug.apk >/dev/null 2>&1; then
  adb uninstall com.faizififita.verses >/dev/null
  adb install app/build/outputs/apk/debug/app-debug.apk >/dev/null
fi
adb shell pm grant com.faizififita.verses android.permission.RECORD_AUDIO
adb shell am start -n com.faizififita.verses/.MainActivity >/dev/null
echo "Verses is running in the emulator. Your Mac's microphone is its microphone."
