# Release scripts

## One-time setup: App Store Connect API key

`push-build.sh` uploads without Xcode's UI, which needs an API key rather than your Apple ID.

1. App Store Connect → **Users and Access → Integrations → App Store Connect API**.
2. Create a key with the **App Manager** role. Download the `.p8` — it downloads once only.
3. Move it where the script looks for it:

   ```
   mkdir -p ~/.appstoreconnect/private_keys
   mv ~/Downloads/AuthKey_XXXXXXXXXX.p8 ~/.appstoreconnect/private_keys/
   ```

4. Copy the **Key ID** (next to the key) and the **Issuer ID** (above the key list) into
   `scripts/release.env`, which is gitignored:

   ```
   ASC_KEY_ID=XXXXXXXXXX
   ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   ```

## Pushing a build

```
scripts/push-build.sh                 # bump build number, archive, upload, commit + tag
scripts/push-build.sh --version 1.2   # also set the marketing version
scripts/push-build.sh --export-only   # signed .ipa in build/, no upload, no key needed
```

The script refuses to run on a dirty working tree, then archives Release for a generic iOS
device, uploads via `xcodebuild -exportArchive` with `destination: upload`, and tags the
release `v<version>-<build>`. Those tags are the anchor for diffing "everything since the
last release" when writing release notes.

Version numbers live in `project.pbxproj`; `project_version.py` reads and writes them for
the app target only (the test target's numbers are left alone).

After upload, the build takes a few minutes to process before it can be attached to a
version in App Store Connect.

## Preparing the release

```
scripts/release-diff.sh          # commits + changed areas since the newest v* tag
scripts/release-diff.sh <ref>    # or from an explicit base, before any tag exists
scripts/check-listing.py         # numeric claims in store-listing.md vs library.json
```

`release-diff.sh` groups changed files by area so it's obvious at a glance whether a
release contains anything user-facing at all. `check-listing.py` counts the bundled
library by collection and compares it against the claims in `store-listing.md` — it exits
non-zero when a number has drifted.

Both feed the `release` skill (`.claude/skills/release/`), which is the front door for all
of this: ask to ship a release and it diffs since the last tag, drafts the "What's New"
copy, checks the listing claims, names any screenshots the release invalidated, recommends
a version, and — only once you say yes — runs `push-build.sh` for you.
