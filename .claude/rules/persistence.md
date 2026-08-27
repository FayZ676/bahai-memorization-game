---
paths:
  - "MemorizationGame/Model/**/*.swift"
  - "MemorizationGame/Store/**/*.swift"
---

# Persistence and back-compat

`Codable` conformance on `Passage` and `Reviewable` is hand-written for backward compatibility
with snapshots already on users' devices. When adding a field, decode it with `decodeIfPresent`
plus a fallback — an existing saved JSON must still load.

Every store mutation persists. If you add one, make sure it saves.
`RecitationLog.swift` persists the last few recitation attempts per chunk to `recitation-log.json`.
