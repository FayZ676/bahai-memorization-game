---
paths:
  - "scripts/**"
  - "store-listing.md"
  - "store-screenshots/**"
---

# Releasing

`/release` is the single door for shipping — it drives the helpers in `scripts/`
(`release-diff.sh`, `check-listing.py`, `project_version.py`, `push-build.sh`), then
submits through the user-level `app-store-connect` skill. Any other change in App Store
Connect (notes, screenshots, listing copy, review) goes through that skill directly.
`scripts/README.md` covers the one-time App Store Connect API key setup.
