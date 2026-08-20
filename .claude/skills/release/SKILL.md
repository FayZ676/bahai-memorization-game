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
grep -c INFOPLIST_KEY_ITSAppUsesNonExemptEncryption MemorizationGame.xcodeproj/project.pbxproj
```

- **Dirty tree** — stop and show what's uncommitted. Committing it is the user's call.
- **No tag yet** (true until the first scripted release): the base is the commit that set
  the current build number. Find it with
  `git log -S"CURRENT_PROJECT_VERSION = <build>;" -- MemorizationGame.xcodeproj/project.pbxproj`
  and confirm it with the user before leaning on it. Do not diff the whole history.
- **No `scripts/release.env` or no `.p8` key** — phases 1–4 still work. Say up front that
  phase 5 will not be possible until the key is set up per `scripts/README.md`.
- **Encryption key missing** (the grep returns 0) — a build without
  `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` lands in App Store Connect as "Missing
  Compliance" and cannot be submitted until someone answers the export questionnaire by
  hand. Restore it on both the Debug and Release configurations of the app target before
  archiving. It must stay a build setting, not a hand-answered prompt: Xcode coerces it to
  a real boolean in the generated `Info.plist`, which is what Apple reads.

  The declaration is only honest while the app's only encryption is Apple's own
  HTTPS — today that is `Support/FeedbackForm.swift` posting to the Google Form, and
  nothing else. If a release ever adds custom cryptography, its own TLS stack, or ships an
  encryption library, this answer stops being true and the exemption has to be re-decided
  rather than carried forward.

## Phase 1 — Gather

```
scripts/release-diff.sh <base>
python3 scripts/check-listing.py
```

Read the commit bodies, not just the subjects. This repo writes real ones, and they say
why a change happened, which is what the notes need. Where a subject is unclear, read that
commit's diff.

## Phase 2 — Draft the notes

The notes are written twice, from one set of beats: the App Store paragraphs and the
in-app What's New card. Draft the paragraphs first, then turn the same beats into
highlights.

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

Land them in `store-listing.md` as a new `## What's New — <X.Y> (4000)` section above the
previous one, in the same commit as the card below, so the file never skips a version.

### The in-app card

`MemorizationGame/Feature/ReleaseNotes/ReleaseNotes.swift` holds the card the app shows on
the first launch of a new version. **Every release adds an entry, and the release is not
ready until it does** — a version with no entry shows nobody anything, and the Settings
"What's new" row keeps offering the release before it.

Prepend a `ReleaseNote` to `ReleaseNotes.all`; newest first is what `latest` means.

- `version` is the marketing version being shipped, exactly as `project_version.py` will
  write it — `"1.7"`, not `"1.7.0"`. A mismatch is silent: the card simply never appears.
- `headline` is one sentence on the shape of the release, the same beat the App Store
  paragraphs lead with.
- Three to five `highlights`, one per change worth naming. Each has an SF Symbol the app
  already uses for that thing (`mic`, `eye`, `waveform`, `trophy`, `book`), a two-to-four
  word `title`, and a `text` of a sentence or two.
- The card scrolls past five, but a release that needs more is a release whose notes are
  not filtered enough.
- Same filter as the paragraphs: if a change is invisible to someone using the app, it does
  not earn a highlight, and "Small fixes and refinements" is not a highlight — leave it to
  the App Store copy.

Write the card for someone who has never used the app, knows no computer words, and reads
only basic English. This is stricter than the App Store copy:

- Short, common words and short sentences. "Slide the page up", not "swipe to advance".
- Say where a thing is and what happens when you touch it: "Tap the eye next to the
  microphone." Never name a part of the app the reader would have to already know —
  no "the rail", "the session", "sections", "recitation".
- Describe what the reader does and sees, never how it was built. No screen names, no
  settings names, no words like sync, cache, gesture, engine, on-device.
- No numbers, versions, or measurements in the text.

Check it renders before shipping: Settings → **What's new** always shows the newest entry,
whatever version is installed, so the card can be read on device before the version is
bumped.

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

Present, in this order: the draft notes, the highlights going into the in-app card, the
listing findings, the screenshot verdict, and the recommended version. Then ask whether to
ship.

Stop here if anything in phase 3 needs the user's hand first — stale copy is worth fixing
before the build goes up, not after.

## Phase 5 — Ship

Only on an explicit yes. First commit the notes — `store-listing.md` and the new
`ReleaseNote` — and confirm that entry's `version` is the version about to be passed to
`--version`. `push-build.sh` refuses a dirty tree, so this has to land first either way.

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

Export compliance is **not** on that list: phase 0 verified the build carries the
exemption, so the build should arrive submittable rather than "Missing Compliance". If it
still shows that status, the key did not reach the archive — check it survived in both
configurations rather than answering the prompt by hand, since a hand-answered build fixes
one upload and leaves the next one broken.
