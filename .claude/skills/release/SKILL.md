---
name: release
description: Run a full App Store release of Verses end to end — diff since the last release, draft the What's New notes, check the listing copy and screenshots, bump the version, and upload the build to App Store Connect. Use when submitting a new version, shipping a release, preparing App Store notes, or asking what changed since the last release.
---

# Release Verses

One pass from "what changed" to "the build is uploading". Work through the phases in
order. Phases 1–4 are analysis and cost nothing; phase 5 uploads and is the only
irreversible step, so it never runs without the user saying yes.

If the user only wants part of this — just the notes, just the push — do that part and
skip the rest.

## Phase 0 — Pre-flight

```
git status --porcelain                              # must be clean
git tag --list 'v*' --sort=-creatordate | head -1   # the diff base
python3 scripts/project_version.py --get marketing
python3 scripts/project_version.py --get build
```

- **Dirty tree** — stop and show what's uncommitted. Committing it is the user's call.
- **No tag yet** (true until the first scripted release): the base is the commit that set
  the current build number. Find it with
  `git log -S"CURRENT_PROJECT_VERSION = <build>;" -- MemorizationGame.xcodeproj/project.pbxproj`
  and confirm it with the user before leaning on it. Do not diff the whole history.
- **No `scripts/release.env` or no `.p8` key** — phases 1–4 still work. Say up front that
  phase 5 will not be possible until the key is set up per `scripts/README.md`.

## Phase 1 — Gather

```
scripts/release-diff.sh <base>
python3 scripts/check-listing.py
```

Read the commit bodies, not just the subjects. This repo writes real ones, and they say
why a change happened, which is what the notes need. Where a subject is unclear, read that
commit's diff.

## Phase 2 — Draft the notes

Include a change only if a person using the app would notice it. The "Files by area"
section is the first filter:

| Area | Usually |
|---|---|
| `app: Library`, `Session`, `Import`, `Settings`, `Achievements`, `Onboarding` | user-facing — describe it |
| `app: Theme`, `Typography` | user-facing only if the look visibly changed |
| `content: library + resources` | user-facing if passages were added or removed — say how many |
| `app: Store`, `Model`, `Logic`, `Support` | usually invisible; mention only if behaviour changed |
| `design:`, `store:`, `support:`, `docs/`, `scripts/` | never — these ship nothing to users |

A release whose diff is entirely store tiles and scripts has **no** notes to write. Say so
plainly rather than inventing improvements; use "Small fixes and refinements."

Match the voice of `store-listing.md` — calm, plain, second person, concrete. Read it
before drafting.

- Lead with the change someone would be gladdest to find.
- One line per change, none longer than a sentence and a half.
- Name things as the app names them — "Writings", "passages", "hide a word".
- No exclamation marks, no "we're excited to", no version numbers, no bug-ticket voice.
- Say what it does for the reader, not what was implemented.
- Never advertise the review prompt or analytics-shaped plumbing.
- Fixes get one grouped line at the end unless a fix is the headline.
- Usually under 500 characters; the hard limit is 4000.

## Phase 3 — Check the listing and screenshots

**Listing copy.** Report `check-listing.py`'s result. Then read the description for prose
the checker cannot count — a new surface it doesn't mention, a promise the release just
made false, a privacy claim that changed. Quote the exact line that needs editing. The
"Notes / decisions still open" section of `store-listing.md` lists the standing claims to
re-verify before every submit; walk them.

**Screenshots.** The five uploaded tiles are `store-screenshots/iphone-6.9-framed/`, built
from raw captures — `store-screenshots/README.md` maps them. Flag a tile only when this
release changed what that tile actually shows:

| Changed | Restages |
|---|---|
| `Feature/Library` | `5-know.png` (library, streak, progress ramps) |
| `Feature/Session` layout | `2-read.png`, `3-hide.png`, `4-hide-more.png` — reshoot as a set |
| Writings surface (`Feature/Import`) | `1-choose.png` |
| `Theme/`, `Typography` globally | all of them |
| the hero passage in `tools/seed.py` | `2-read`, `3-hide`, `4-hide-more` as a set |

Behaviour changes that don't alter what's on screen do not need a reshoot — check the diff
before flagging. `8-achievements.png` is a spare that is not uploaded. Flagging is the
job: never regenerate screenshots unless asked, since reshooting is a driven simulator
session documented in that README.

**Version.** Recommend one. Fixes and refinements are a patch bump; a new surface or
capability is a minor bump.

## Phase 4 — Show the user

Present, in this order: the draft notes, the listing findings, the screenshot verdict, and
the recommended version. Then ask whether to ship.

Stop here if anything in phase 3 needs the user's hand first — stale copy is worth fixing
before the build goes up, not after.

## Phase 5 — Ship

Only on an explicit yes:

```
scripts/push-build.sh --version <X.Y>
```

It bumps the build number, archives, uploads, then commits and tags the release. It takes
a few minutes and streams a lot of output; report the tag it created and whether the
upload succeeded.

Then tell the user what is left by hand, because none of it is automatable from here:

- The build takes minutes to process before it can be attached to a version.
- Paste the notes into App Store Connect against that build. Never post them anywhere
  automatically — that review step is deliberate.
- Any screenshot or copy fix phase 3 flagged.
- If this is the first release that ships the feedback screen, the privacy nutrition label
  must be updated from "Data Not Collected" — `store-listing.md` records the exact answers.
