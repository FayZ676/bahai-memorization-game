# App Store listing — Verses

## Name (30)
Verses

## Subtitle (30)
Memorize Bahá'í prayers

## Keywords (100)
bahai,hidden,words,ruhi,quotes,writings,obligatory,bahaullah,abdul,baha,scripture,memory,bab

## Promotional text (170)
225 prayers, all 153 Hidden Words, and 249 Ruhi quotations — built in. Hide a word, recite what's left, and let the passage teach itself to you.

## Description (4000)
Verses turns prayers you love into prayers you know by heart.

Tap a word to hide it. What's left is a prompt — read the passage aloud and your memory fills the gap. Hide a few more each time you return, until the page is empty and the prayer is yours.

THE LIBRARY IS ALREADY THERE
• 225 prayers — obligatory, general, occasional, and special tablets
• The Hidden Words of Bahá'u'lláh, all 153
• 249 Ruhi quotations — every one the courses ask you to memorize, Books 1 through 8
• Writings of Bahá'u'lláh, 'Abdu'l-Bahá, and the Báb
Search for a half-remembered phrase, or browse by section. Nothing to download.

MEMORIZE AT YOUR OWN PACE
• Tap any word to hide it — tap again to bring it back
• Long-press the passage to hide or reveal all of it at once
• Long prayers divide into short passages you can move between freely
• Nothing is locked, timed, or gated — start anywhere, stop anywhere

RECITE ALOUD
• Speak the passage and Verses follows you word by word
• Speech recognition happens on your device

BRING YOUR OWN
• Paste any text you want to learn — a quotation, a poem, a passage in any language
• Break it into passages wherever the meaning breaks

QUIET BY DESIGN
• No account, no sign-in
• Your passages, your progress, and your recordings stay on your iPhone — nothing is sent unless you send a report
• No ads, no leaderboards, and reminders only if you ask for them
• A simple record of how many words you've hidden each day — encouragement, not obligation

Verses is built around one belief: memorization isn't a test to pass, it's a way of carrying words with you. Hide what you know. Read what you don't. Come back tomorrow.

## What's New — 1.6 (4000)
Prayers you've finished can now be archived. Swipe a prayer in your library to tuck it into an Archived section, and swipe again to bring it back.

Reciting aloud no longer holds you to strict order. A word you've already read past can still be said and counted, instead of being marked missed however clearly you say it.

The record of what the app heard now has its own row in Settings. It keeps more than misses — words you never said and words that took a few tries are each listed and colour-coded, with filters for reading just one kind.

Small fixes and refinements.

## What's New — 1.5 (4000)
Verses now opens on the nine-pointed star from the app icon, which fades away and hands off to your library.

The app icon itself has been redrawn, with the star fading more gently across the face.

Small fixes and refinements.

## What's New — 1.4 (4000)
Ruhi is now all eight books. Where there was only Book 1, there are 249 quotations — every passage the courses ask you to memorize, through to The Covenant of Bahá'u'lláh.

Reciting aloud is far more accurate. Words are marked as you speak rather than all at once at the end, and a word the app mishears no longer counts against you. You can also recite only the words you've hidden and leave the rest unsaid.

The welcome tour now starts you on a Hidden Word and shows you how to move between a passage's sections.

An empty library offers a way straight into the writings, along with small fixes and refinements.

## What's New — 1.3 (4000)
When you recite aloud, the passage now follows you — the page scrolls to keep the word you're on in view, from the moment you press record.

If a word you said gets counted as missed, there's now a Report Issue screen in Settings and in the session menu. It sends what the app heard alongside your note, so it can be fixed.

Long passages scroll and respond more smoothly, along with small fixes and refinements.

## What's New — 1.2 (4000)
Achievements now go by the kind of prayer rather than one particular prayer — memorize any morning prayer, any healing prayer, any prayer for the Fast, and it counts.

Settings has a new Send feedback row for writing in from inside the app, and a link to the privacy policy at the foot.

The welcome tour now points you to the achievements before it finishes.

Small fixes and refinements.

---

## Support / Privacy URLs
- Support: https://fayz676.github.io/bahai-memorization-game/
- Privacy: https://fayz676.github.io/bahai-memorization-game/privacy.html

## Screenshots
Upload the `-framed/` folders in filename order — 5 × iPhone 6.9" (1320×2868) and
3 × iPad 13" (2064×2752), each a screenshot composed under a headline by
`Design/StoreFrames/`. They read as one pass through the app: choose a prayer, hide a
word, hide more, say it out loud, know it. The closing tile is dark, which is where the
app's dark appearance gets shown. The bare folders in `store-screenshots/` are the raw
captures those are built from, with regeneration instructions.

The recitation tile is staged with a DEBUG-only `SHOT_RECITING=1`, since the simulator can
never reach the listening state on its own — see `store-screenshots/README.md`. The iPad set
has no recitation tile.

## Notes / decisions still open
- **Pricing** — description says "no ads, no sign-in" but deliberately does NOT claim "free" or "no subscription", since pricing isn't decided. Add if free.
- **On-device speech** — SpeechAnalyzer (iOS 26) processes on device; verify before shipping since it's a privacy claim.
- **Privacy nutrition label** — no longer "Data Not Collected": the Settings feedback screen posts to a
  Google Form. Declare, all with purpose "App Functionality", linked to the user, not used for tracking:
  Contact Info → Email Address (optional); User Content → Customer Support (the message);
  Diagnostics → Other Diagnostic Data (app version, device model, iOS version).
  Nothing else is collected — passages, progress and audio stay on device.
- **Revisit keywords** after ~1 month of App Store Connect search-term data. The current set
  is reasoned, not measured — there is no impressions data behind it yet.
  Only the name, subtitle and keyword field are indexed; the description is not, so nothing
  is gained by wording it for search. Apple combines tokens across those fields into
  phrases, so a keyword's job is to complete a phrase rather than to stand alone: `verses`
  comes from the name and `memorize`/`bahai`/`prayers` from the subtitle, which is why none
  of them are repeated here and why `obligatory` alone buys "obligatory prayers".
  Matching is by whole token, so a run-together spelling cannot match a spaced query —
  `abdul,baha` covers "abdul baha", `abdulbaha` never did.
  `faith` and `recite` were dropped: "bahai faith" is high volume but wants an
  informational app, and recitation is the mechanic rather than the thing people search for.
  `bahai` is kept despite the subtitle already carrying "Bahá'í", since it is the one term
  the app cannot afford to miss if diacritic folding behaves unexpectedly — drop it for a
  wider term only once search data shows the subtitle is covering it.
