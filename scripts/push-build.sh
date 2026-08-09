#!/bin/bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$REPO/MemorizationGame.xcodeproj"
SCHEME="MemorizationGame"
BUILD_DIR="$REPO/build"
ARCHIVE="$BUILD_DIR/$SCHEME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"
TEAM_ID="WG5M4FAV79"
VERSION_TOOL="$REPO/scripts/project_version.py"

marketing_version=""
build_number=""
bump=1
tag=1
export_only=0
allow_dirty=0

usage() {
  cat <<'EOF'
Usage: scripts/push-build.sh [options]

Bumps the build number, archives Release, and uploads to App Store Connect.

  --version X.Y     set the marketing version (default: leave as is)
  --build N         use this build number instead of bumping
  --no-bump         keep the current build number
  --no-tag          skip the git commit + tag for this release
  --export-only     export a signed .ipa to build/export without uploading
  --allow-dirty     proceed with uncommitted changes
  -h, --help        show this message

Credentials come from scripts/release.env or the environment:
  ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH (default ~/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) marketing_version="$2"; shift 2 ;;
    --build) build_number="$2"; bump=0; shift 2 ;;
    --no-bump) bump=0; shift ;;
    --no-tag) tag=0; shift ;;
    --export-only) export_only=1; shift ;;
    --allow-dirty) allow_dirty=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -f "$REPO/scripts/release.env" ]]; then
  set -a
  source "$REPO/scripts/release.env"
  set +a
fi

if [[ $export_only -eq 0 ]]; then
  : "${ASC_KEY_ID:?set ASC_KEY_ID in scripts/release.env — see scripts/README.md}"
  : "${ASC_ISSUER_ID:?set ASC_ISSUER_ID in scripts/release.env — see scripts/README.md}"
  ASC_KEY_PATH="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8}"
  if [[ ! -f "$ASC_KEY_PATH" ]]; then
    echo "App Store Connect key not found at $ASC_KEY_PATH — see scripts/README.md" >&2
    exit 1
  fi
fi

cd "$REPO"

if [[ $allow_dirty -eq 0 && -n "$(git status --porcelain)" ]]; then
  echo "working tree is dirty; commit first or pass --allow-dirty" >&2
  exit 1
fi

if [[ -n "$marketing_version" ]]; then
  python3 "$VERSION_TOOL" --set-marketing "$marketing_version"
fi

if [[ $bump -eq 1 ]]; then
  build_number=$(( $(python3 "$VERSION_TOOL" --get build) + 1 ))
fi
if [[ -n "$build_number" ]]; then
  python3 "$VERSION_TOOL" --set-build "$build_number"
fi

marketing_version=$(python3 "$VERSION_TOOL" --get marketing)
build_number=$(python3 "$VERSION_TOOL" --get build)
release="$marketing_version ($build_number)"
echo "==> Releasing $release"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Archiving"
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates

if [[ $export_only -eq 1 ]]; then
  destination="export"
else
  destination="upload"
fi

cat > "$EXPORT_OPTIONS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>$destination</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
EOF

echo "==> Exporting ($destination)"
export_args=(
  -exportArchive
  -archivePath "$ARCHIVE"
  -exportPath "$EXPORT_DIR"
  -exportOptionsPlist "$EXPORT_OPTIONS"
  -allowProvisioningUpdates
)
if [[ $export_only -eq 0 ]]; then
  export_args+=(
    -authenticationKeyPath "$ASC_KEY_PATH"
    -authenticationKeyID "$ASC_KEY_ID"
    -authenticationKeyIssuerID "$ASC_ISSUER_ID"
  )
fi
xcodebuild "${export_args[@]}"

if [[ $export_only -eq 1 ]]; then
  echo "==> Exported to $EXPORT_DIR (not uploaded)"
  exit 0
fi

if [[ $tag -eq 1 ]]; then
  git add MemorizationGame.xcodeproj/project.pbxproj
  if ! git diff --cached --quiet; then
    git commit -m "Bump to $release"
  fi
  git tag -a "v$marketing_version-$build_number" -m "$release"
  echo "==> Tagged v$marketing_version-$build_number"
fi

echo "==> Uploaded $release to App Store Connect"
echo "    Processing takes a few minutes; then set the build on the version in App Store Connect."
