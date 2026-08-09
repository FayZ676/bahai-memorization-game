#!/bin/bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

base="${1:-}"
if [[ -z "$base" ]]; then
  base="$(git tag --list 'v*' --sort=-creatordate | head -1)"
fi

if [[ -z "$base" ]]; then
  echo "No release tag found, and no base given."
  echo "Pass one explicitly, e.g. scripts/release-diff.sh <tag-or-sha>."
  echo "After the next scripts/push-build.sh run there will be a tag to diff against."
  exit 1
fi

if ! git rev-parse --verify --quiet "$base" >/dev/null; then
  echo "not a ref: $base" >&2
  exit 1
fi

range="$base..HEAD"
count=$(git rev-list --count "$range")

echo "# Changes since $base"
echo
echo "$count commits on $(git rev-parse --abbrev-ref HEAD)"
echo

if [[ "$count" -eq 0 ]]; then
  echo "Nothing to release."
  exit 0
fi

echo "## Commits"
echo
git log --reverse --format='- %s%n%w(0,2,2)%b' "$range" \
  | grep -vE '^\s*(Co-Authored-By|Claude-Session|Generated with):' \
  | cat -s
echo
echo "## Files by area"
echo
git diff --name-only "$range" | awk -F/ '
  /^MemorizationGame\/Feature\// { print "app: " $3; next }
  /^MemorizationGame\/(Store|Model|Logic|Support)\// { print "app: " $2; next }
  /^MemorizationGame\/Theme\// { print "app: Theme"; next }
  /^MemorizationGame\/Resources\// { print "content: library + resources"; next }
  /^MemorizationGame\// { print "app: other"; next }
  /^store-screenshots\// { print "store: screenshots"; next }
  /^store-listing/ { print "store: listing copy"; next }
  /^Design\// { print "design: " $2; next }
  /^(docs|scripts|Tools)\// { print "support: " $1; next }
  { print "other: " $1 }
' | sort | uniq -c | sort -rn

echo
echo "## User-facing app diff"
echo
git diff --stat "$range" -- 'MemorizationGame/*'
