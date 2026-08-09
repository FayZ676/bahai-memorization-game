---
name: release-notes
description: Draft the App Store "What's New" text for the next release of Verses, and flag whether the screenshots or listing copy have gone stale. Use when preparing an App Store submission, writing release notes, or asking what changed since the last release.
---

# Release notes for Verses

Turns everything since the last release tag into App Store "What's New" copy, and reports
what else the release needs before it can be submitted.

## 1. Gather

```
scripts/release-diff.sh            # since the newest v* tag
scripts/release-diff.sh <ref>      # or an explicit base
scripts/check-listing.py           # numeric claims vs the bundled library
```

If no tag exists yet, ask which commit the last submitted build came from rather than
guessing — the whole history is not the diff.

Read the commit bodies, not just the subjects. This repo writes real ones, and they say
why a change happened, which is what the notes need. Where a subject is unclear, read the
diff for that commit.

## 2. Decide what is user-facing

Most commits do not belong in release notes. Include a change only if a person using the
app would notice it. The "Files by area" section of the diff is the first filter:

| Area | Usually |
|---|---|
| `app: Library`, `Session`, `Import`, `Settings`, `Writings` | user-facing — describe it |
| `app: Theme`, `Typography` | user-facing only if the look visibly changed |
| `content: library + resources` | user-facing if passages were added or removed — say how many |
| `app: Store`, `Model`, `Logic` | usually invisible; mention only if behaviour changed |
| `design:`, `store:`, `support:`, `docs/`, `scripts/` | never — these ship nothing to users |

A release whose diff is entirely store tiles and scripts has **no** release notes to write.
Say so plainly rather than inventing improvements; use "Small fixes and refinements."

## 3. Write

Match the voice of `store-listing.md`: calm, plain, second person, concrete. That listing
is the reference — read it before drafting.

- Lead with the change someone would be gladdest to find.
- One line per change. No bullets longer than a sentence and a half.
- Name the thing as the app names it — "Writings", "passages", "hide a word".
- No exclamation marks, no "we're excited to", no version numbers, no bug-ticket voice.
- Say what it does for the reader, not what was implemented: "Prayers you've read
  recently are easier to find again", not "Added recentPrayerIDs to the Writings surface."
- Fixes get one grouped line at the end unless a fix is the headline.
- Well under the 4000-character limit — these run short, usually under 500.

Show the draft in the conversation for approval before writing it anywhere.

## 4. Report what else the release needs

Alongside the draft, state each of these plainly:

**Listing copy** — report `check-listing.py`'s result. If a claim is stale, quote the line
of `store-listing.md` that needs changing. Also flag by hand any change that contradicts
prose the checker cannot count: a new surface the description doesn't mention, a dropped
feature it still promises, a privacy-relevant change (the "Notes / decisions still open"
section of `store-listing.md` lists the claims that need re-verifying before each submit).

**Screenshots** — the five uploaded tiles live in `store-screenshots/iphone-6.9-framed/`
and are built from raw captures; `store-screenshots/README.md` maps them. Flag a tile as
stale when the release changed what it shows:

| Changed | Restages |
|---|---|
| `Feature/Library` | `5-know.png` (library, streak, progress ramps) |
| `Feature/Session` | `2-read.png`, `3-hide.png`, `4-hide-more.png` — reshoot as a set |
| Writings surface | `1-choose.png` |
| `Theme/`, `Typography` | all of them |
| the hero passage in `tools/seed.py` | `2-read`, `3-hide`, `4-hide-more` as a set |

Flagging is the job — do not regenerate screenshots unless asked. Reshooting is a
simulator session documented in `store-screenshots/README.md`.

**Version** — recommend a marketing version. Bug fixes and small refinements are a patch
bump; a new surface or capability is a minor bump. `scripts/push-build.sh --version X.Y`
sets it; the build number bumps itself.

## 5. Hand off

End with the exact command to ship it:

```
scripts/push-build.sh --version 1.2
```

Then the notes get pasted into App Store Connect against the build once it finishes
processing. Do not paste release notes anywhere automatically — App Store Connect is the
only place they go, and that is a manual review step by design.
