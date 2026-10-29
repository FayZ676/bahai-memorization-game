---
paths:
  - "MemorizationGame/Model/**/*.swift"
  - "MemorizationGame/Store/**/*.swift"
---

# Persistence and back-compat

`Codable` conformance on `Passage` is hand-written for backward compatibility with snapshots
already on users' devices. The store lives in `verses.json`; 2.0 started everyone fresh and deletes
the old chunked `store.json` and `recitation-log.json` on launch — a user who had them is treated
as returning (no welcome tour; the 2.0 What's New explains the reset). When adding a field, decode it with `decodeIfPresent`
plus a fallback — an existing saved JSON must still load.

Every store mutation persists. If you add one, make sure it saves.
