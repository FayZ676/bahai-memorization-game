#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$ANDROID_DIR"

[ -f keystore.properties ] || { echo "keystore.properties is missing — see android/README.md"; exit 1; }
./gradlew -q :logic:test :app:bundleRelease
echo "Upload this to Play Console:"
echo "  $ANDROID_DIR/app/build/outputs/bundle/release/app-release.aab"
grep -E "versionCode|versionName" app/build.gradle.kts | sed 's/^ */  /'
