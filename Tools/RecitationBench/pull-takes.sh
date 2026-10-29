#!/bin/bash
set -euo pipefail

bundle=com.faizififita.MemorizationGame
takes="$(cd "$(dirname "$0")" && pwd)/takes"
listing="$(mktemp)"
trap 'rm -f "$listing"' EXIT

device="${1:-$(xcrun devicectl list devices 2>/dev/null | grep 'available (paired)' | grep -oE '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}' | head -1)}"
if [ -z "$device" ]; then
    echo "No paired iPhone is available. Connect it, or pass its identifier." >&2
    exit 1
fi

xcrun devicectl device info files --device "$device" --domain-type appDataContainer \
    --domain-identifier "$bundle" --subdirectory Documents/Bench > "$listing"

pulled=0
for stem in $(grep -oE 'bench-[^ /]+\.wav' "$listing" | sed 's/\.wav$//' | sort -u); do
    [ -f "$takes/$stem.wav" ] && continue
    for extension in wav json; do
        xcrun devicectl device copy from --device "$device" --domain-type appDataContainer \
            --domain-identifier "$bundle" --source "Documents/Bench/$stem.$extension" \
            --destination "$takes/$stem.$extension" > /dev/null
    done
    echo "pulled $stem"
    pulled=$((pulled + 1))
done
echo "$pulled new takes in $takes"
