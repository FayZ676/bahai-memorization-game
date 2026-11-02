#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$ANDROID_DIR"

out="$ANDROID_DIR/build/bench-kotlin.json"
./gradlew -q :logic:bench -PbenchArgs="Tools/RecitationBench/takes android/app/src/main/assets/conformer.onnx MemorizationGame/Resources/conformer-vocabulary.json $out"
python3 ../Tools/RecitationBench/candidates/evaluate.py ../Tools/RecitationBench/takes "$out" --threshold -1 | tail -3
