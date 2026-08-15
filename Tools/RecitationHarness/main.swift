import Foundation

var failures = 0
func check(_ label: String, _ condition: Bool, _ detail: @autoclosure () -> String = "") {
    if condition { print("  ok   \(label)") }
    else { failures += 1; print("  FAIL \(label) \(detail())") }
}

print("PhoneticKey equivalences")
for (a, b) in [("Thy", "the"), ("Thee", "the"), ("Thou", "though"), ("hath", "has"), ("art", "are"), ("unto", "into"), ("Thy", "that"), ("Thee", "these")] {
    check("\(a) ~ \(b)", PhoneticKey.matches(PhoneticKey.encode(b), PhoneticKey.encode(a)),
          "[\(PhoneticKey.encode(a)) vs \(PhoneticKey.encode(b))]")
}
print("PhoneticKey separations")
for (a, b) in [("God", "Lord"), ("Son", "Spirit"), ("mercy", "bounty"), ("light", "night")] {
    check("\(a) != \(b)", !PhoneticKey.matches(PhoneticKey.encode(b), PhoneticKey.encode(a)),
          "[\(PhoneticKey.encode(a)) vs \(PhoneticKey.encode(b))]")
}

func heard(_ text: String, confidence: Double = 1.0) -> [RecitationMatcher.HeardToken] {
    text.split(whereSeparator: { $0 == " " || $0 == "-" })
        .map { .init(text: $0, confidence: confidence) }
}
func isMiss(_ event: RecitationMatcher.Event) -> Bool {
    if case .missed = event { return true }
    return false
}

let line = "O Son of Spirit My first counsel is this"
let words = line.split(separator: " ").map(String.init)

print("\nClean recitation, single final")
var clean = RecitationMatcher(words: words, hiddenIndices: [1, 3, 6])
let cleanEvents = clean.ingest(heard(line), isFinal: true)
check("all three matched", cleanEvents == [.matched(index: 1), .matched(index: 3), .matched(index: 6)], "\(cleanEvents)")
check("complete", clean.isComplete)

print("\nASR returns 'the' for 'Thy'")
let thy = ["Thy", "loving", "kindness", "hath", "encompassed", "me"]
var thyMatcher = RecitationMatcher(words: thy, hiddenIndices: [0, 3])
let thyEvents = thyMatcher.ingest(heard("the loving kindness has encompassed me"), isFinal: true)
check("Thy and hath matched", thyEvents == [.matched(index: 0), .matched(index: 3)], "\(thyEvents)")

print("\nRegression: growing volatile segment must not lose a correct word")
let bearLine = ["I", "bear", "witness", "O", "my", "God", "that", "Thou", "hast", "created", "me"]
var bearMatcher = RecitationMatcher(words: bearLine, hiddenIndices: [0, 1, 2, 3, 4, 5])
var bearEvents: [RecitationMatcher.Event] = []
for volatileText in ["I", "I bear", "I bear w", "I bear wit", "I bear witness", "I bear witness, O", "I bear witness, O my"] {
    bearEvents += bearMatcher.ingest(heard(volatileText), isFinal: false)
}
bearEvents += bearMatcher.ingest(heard("I bear witness, O my God."), isFinal: true)
check("bear matched", bearEvents.contains(.matched(index: 1)), "\(bearEvents)")
check("nothing missed", !bearEvents.contains(where: isMiss), "\(bearEvents)")
check("each word announced once", Set(bearEvents.map { if case .matched(let i) = $0 { return i } else { return -1 } }).count == bearEvents.count, "\(bearEvents)")

print("\nRegression: junk finals must not discard volatile progress")
let peril = ["there", "is", "none", "other", "God", "but", "Him", "the", "Help", "in", "Peril", "the", "Self-Subsisting"]
var perilMatcher = RecitationMatcher(words: peril, hiddenIndices: [6, 7, 8, 9, 10])
var perilEvents: [RecitationMatcher.Event] = []
perilEvents += perilMatcher.ingest(heard("there is none other God but"), isFinal: true)
perilEvents += perilMatcher.ingest(heard("The"), isFinal: false)
perilEvents += perilMatcher.ingest(heard(".", confidence: 0.0), isFinal: true)
perilEvents += perilMatcher.ingest(heard("him the help"), isFinal: false)
perilEvents += perilMatcher.ingest(heard("him the help in"), isFinal: false)
perilEvents += perilMatcher.ingest(heard("him the help in peril"), isFinal: false)
perilEvents += perilMatcher.ingest(heard("to..", confidence: 0.01), isFinal: true)
perilEvents += perilMatcher.ingest(heard("him the help in peril the self-subsisting"), isFinal: false)
check("Help matched", perilEvents.contains(.matched(index: 8)), "\(perilEvents)")
check("Peril matched", perilEvents.contains(.matched(index: 10)), "\(perilEvents)")
check("no misses from junk finals", !perilEvents.contains(where: isMiss), "\(perilEvents)")

print("\nFumble then speak straight past it")
var past = RecitationMatcher(words: words, hiddenIndices: [1, 3, 6])
let pastEvents = past.ingest(heard("O banana of Spirit My first counsel"), isFinal: true)
check("word 1 missed as moved-on, later words still matched",
      Set(pastEvents.map(String.init(describing:)))
        == Set([RecitationMatcher.Event.missed(index: 1, movedOn: true), .matched(index: 3), .matched(index: 6)].map(String.init(describing:))),
      "\(pastEvents)")

print("\nRegression: pausing must not flash a miss on the next word")
var paused = RecitationMatcher(words: bearLine, hiddenIndices: [0, 1, 2, 3, 4, 5, 6])
var pausedEvents: [RecitationMatcher.Event] = []
pausedEvents += paused.ingest(heard("I bear witness, O my God"), isFinal: false)
pausedEvents += paused.ingest(heard("I bear witness, O my God,", confidence: 0.9), isFinal: true)
pausedEvents += paused.ingest(heard(".", confidence: 0.0), isFinal: true)
check("no miss when the reciter simply stops", !pausedEvents.contains(where: isMiss), "\(pausedEvents)")
check("still expecting the next unsaid word", paused.nextExpectedIndex == 6, "\(String(describing: paused.nextExpectedIndex))")

print("\nDevice 2026-08-11: a restating final must not miss on stale unaligned tokens")
let prayer = """
O God, my God! My back is bowed by the burden of my sins, and my heedlessness \
hath destroyed me whenever I ponder my evil doings and Thy bounteousness my heart \
melteth within me, and my blood boileth in my veins.
"""
let prayerWords = prayer.split(separator: " ").map(String.init)
var device = RecitationMatcher(
    words: prayerWords,
    hiddenIndices: Array(0...15) + Array(21...27) + Array(29...40)
)
let devicePrefix = """
Oh God, my God my back is bowed by the burden of my sins, and my heedlessness \
had destroyed me whenever I ponder my evil doings
"""
var deviceEvents: [RecitationMatcher.Event] = []
deviceEvents += device.ingest(heard(devicePrefix), isFinal: false)
deviceEvents += device.ingest(heard(devicePrefix + " and"), isFinal: false)
deviceEvents += device.ingest(heard(devicePrefix + " and Lebanon"), isFinal: false)
deviceEvents += device.ingest(heard(devicePrefix + " and Lebanon ambulance"), isFinal: false)
deviceEvents += device.ingest(heard(devicePrefix + " and Lebanon ambulance the"), isFinal: false)
let deviceFinal = device.ingest(
    heard(devicePrefix + " and Lebanon ambulance the", confidence: 0.8),
    isFinal: true
)
check("volatiles credited 'and' and 'Thy'",
      deviceEvents.contains(.matched(index: 26)) && deviceEvents.contains(.matched(index: 27)),
      "\(deviceEvents)")
check("restating final emits no miss on the unsaid next word",
      !deviceFinal.contains(where: isMiss), "\(deviceFinal)")
check("still expecting word 29", device.nextExpectedIndex == 29,
      "\(String(describing: device.nextExpectedIndex))")

print("\nDevice 2026-08-11: a repeated phrase later in the passage must not steal the cursor")
let repeating = """
I testify unto that whereunto have testified all created things and the Concourse \
on high and the inmates of the highest Paradise I testify that Thou art God
"""
let repeatingWords = repeating.split(separator: " ").map(String.init)
var stolen = RecitationMatcher(
    words: repeatingWords,
    hiddenIndices: Array(0..<repeatingWords.count)
)
// The reciter has said "I testify unto that"; the recogniser drops "unto",
// so the spoken keys match the later "I testify that" at zero cost.
_ = stolen.ingest(heard("I testify"), isFinal: false)
let stolenEvents = stolen.ingest(heard("I testify that"), isFinal: false)
check("cursor stays near the opening, not the later repetition",
      (stolen.nextExpectedIndex ?? 99) <= 4,
      "next=\(String(describing: stolen.nextExpectedIndex))")
check("no miss emitted from the volatile", !stolenEvents.contains(where: isMiss), "\(stolenEvents)")
let stolenFinal = stolen.ingest(heard("I testify unto that whereunto"), isFinal: true)
let burned = stolenFinal.filter { if case .missed(_, let movedOn) = $0 { return movedOn } else { return false } }
check("a final must not burn the rest of the passage", burned.count <= 1, "\(burned.count) burned: \(burned)")

print("\nDevice 2026-08-11: the cursor must follow the voice past a soft miss")
var trailing = RecitationMatcher(words: words, hiddenIndices: [1, 3, 6])
_ = trailing.ingest(heard("O"), isFinal: true)
let softMiss = trailing.ingest(heard("banana"), isFinal: true)
check("a soft miss was emitted", softMiss == [.missed(index: 1, movedOn: false)], "\(softMiss)")
check("word 1 is still owed", trailing.nextExpectedIndex == 1,
      "\(String(describing: trailing.nextExpectedIndex))")
_ = trailing.ingest(heard("banana of Spirit"), isFinal: true)
check("cursor moves on with the reciter", trailing.cursorIndex == 6,
      "cursor=\(String(describing: trailing.cursorIndex))")
check("the owed word is still tracked separately", trailing.nextExpectedIndex == 1,
      "\(String(describing: trailing.nextExpectedIndex))")

print("\nRegression: 'O' transcribed as the digit zero")
check("bare 0 encodes as O", PhoneticKey.encode("0") == PhoneticKey.encode("O"),
      "[\(PhoneticKey.encode("0")) vs \(PhoneticKey.encode("O"))]")
var zero = RecitationMatcher(words: bearLine, hiddenIndices: [3])
let zeroEvents = zero.ingest(heard("I bear witness, 0 my god, that"), isFinal: true)
check("O still matched", zeroEvents.contains(.matched(index: 3)), "\(zeroEvents)")
check("O not missed", !zeroEvents.contains(where: isMiss), "\(zeroEvents)")

print("\nRegression: hyphenated word heard as one token")
let subsisting = ["the", "Help", "in", "Peril,", "the", "Self-", "Subsisting."]
var hyphen = RecitationMatcher(words: subsisting, hiddenIndices: [1, 3, 5, 6])
let hyphenEvents = hyphen.ingest(heard("the help in peril, the self-subsisting."), isFinal: true)
check("Self- matched", hyphenEvents.contains(.matched(index: 5)), "\(hyphenEvents)")
check("Subsisting matched", hyphenEvents.contains(.matched(index: 6)), "\(hyphenEvents)")
check("nothing missed", !hyphenEvents.contains(where: isMiss), "\(hyphenEvents)")

print("\nRegression: a transient volatile misread must not commit a miss")
var transient = RecitationMatcher(words: bearLine, hiddenIndices: [6, 7, 8, 9, 10])
var transientEvents: [RecitationMatcher.Event] = []
transientEvents += transient.ingest(heard("that the is created me"), isFinal: false)
check("nothing missed while volatile", !transientEvents.contains(where: isMiss), "\(transientEvents)")
transientEvents += transient.ingest(heard("that Thou hast created me"), isFinal: false)
check("revised hypothesis still matches Thou", transientEvents.contains(.matched(index: 7)), "\(transientEvents)")
check("revised hypothesis still matches hast", transientEvents.contains(.matched(index: 8)), "\(transientEvents)")

print("\nStall and retry: three wrong finals")
var retry = RecitationMatcher(words: words, hiddenIndices: [1, 3, 6])
_ = retry.ingest(heard("O"), isFinal: true)
var attemptEvents: [RecitationMatcher.Event] = []
for _ in 0..<3 { attemptEvents += retry.ingest(heard("banana"), isFinal: true) }
check("two soft misses then a moved-on miss",
      attemptEvents == [.missed(index: 1, movedOn: false), .missed(index: 1, movedOn: false), .missed(index: 1, movedOn: true)],
      "\(attemptEvents)")
check("cursor advanced past the burnt word", retry.nextExpectedIndex == 3, "\(String(describing: retry.nextExpectedIndex))")

print("\nVolatile text never commits a miss")
var volatileMatcher = RecitationMatcher(words: words, hiddenIndices: [1, 3, 6])
let volatileEvents = volatileMatcher.ingest(heard("O banana"), isFinal: false)
check("no miss emitted while volatile", !volatileEvents.contains(where: isMiss), "\(volatileEvents)")

print("\nLow-confidence junk cannot burn an attempt")
var junk = RecitationMatcher(words: words, hiddenIndices: [1, 3, 6])
_ = junk.ingest(heard("O"), isFinal: true)
let junkEvents = junk.ingest(heard(".", confidence: 0.0), isFinal: true)
check("no miss from a zero-confidence token", !junkEvents.contains(where: isMiss), "\(junkEvents)")

print("\nMiss records name the expected word and what was heard in its place")
var recorded = RecitationMatcher(words: words, hiddenIndices: [1, 3, 6])
_ = recorded.ingest(heard("O banana of Spirit My first counsel"), isFinal: true)
check("one miss recorded", recorded.misses.count == 1, "\(recorded.misses)")
check("expected word kept verbatim", recorded.misses.first?.expected == "Son", "\(recorded.misses)")
check("heard word attributed to the gap", recorded.misses.first?.heard == "banana", "\(recorded.misses)")
check("phonetic keys kept for debugging",
      recorded.misses.first?.expectedKey == PhoneticKey.encode("Son")
        && recorded.misses.first?.heardKeys == [PhoneticKey.encode("banana")],
      "\(recorded.misses)")

print("\nA word skipped in silence records nothing heard")
var silent = RecitationMatcher(words: words, hiddenIndices: [1, 3, 6])
_ = silent.ingest(heard("O Son of My first counsel"), isFinal: true)
check("miss recorded for the skipped word", silent.misses.map(\.wordIndex) == [3], "\(silent.misses)")
check("nothing heard in its place", silent.misses.first?.heard.isEmpty == true, "\(silent.misses)")

print("\nStalling records the words heard instead of the owed one")
var stalled = RecitationMatcher(words: words, hiddenIndices: [1, 3, 6])
_ = stalled.ingest(heard("O"), isFinal: true)
for _ in 0..<3 { _ = stalled.ingest(heard("banana"), isFinal: true) }
check("the burnt word is recorded", stalled.misses.map(\.expected) == ["Son"], "\(stalled.misses)")
check("what was heard instead is recorded",
      stalled.misses.first.map { !$0.heard.isEmpty } == true, "\(stalled.misses)")

print("\nDevice 2026-08-14: a word owed behind the frontier can still be said")
let seestLine = "O God my God Thou seest me detached from all save Thee and cleaving unto Thee"
let seestWords = seestLine.split(separator: " ").map(String.init)
check("seest and cyst are the same key",
      PhoneticKey.encode("seest") == PhoneticKey.encode("cyst"),
      "[\(PhoneticKey.encode("seest")) vs \(PhoneticKey.encode("cyst"))]")
var behind = RecitationMatcher(words: seestWords, hiddenIndices: [5, 11, 15])
let recited = behind.ingest(
    heard("O God my God that is me detached from all save and cleaving unto the"),
    isFinal: true
)
check("the misheard word is not credited by the recitation", !recited.contains(.matched(index: 5)),
      "\(recited)")
check("a neighbouring word must not be reclaimed for it", behind.nextExpectedIndex == 5,
      "\(String(describing: behind.nextExpectedIndex))")
let retried = behind.ingest(heard("seest"), isFinal: true)
check("saying it again after passing it now lands", retried.contains(.matched(index: 5)),
      "\(retried)")
check("and the cursor moves to the next owed word", behind.nextExpectedIndex == 11,
      "\(String(describing: behind.nextExpectedIndex))")

print("\nReclaiming demands the same key, not a near one")
var nearby = RecitationMatcher(words: seestWords, hiddenIndices: [5])
_ = nearby.ingest(heard("O God my God that is me detached from all"), isFinal: true)
let wrongWord = nearby.ingest(heard("save"), isFinal: true)
check("a word one edit away does not reclaim the owed word",
      !wrongWord.contains(.matched(index: 5)), "\(wrongWord)")
check("the word is still owed", nearby.nextExpectedIndex == 5,
      "\(String(describing: nearby.nextExpectedIndex))")

print("\nReclaiming never fires on an utterance that moves forward")
var forward = RecitationMatcher(words: seestWords, hiddenIndices: [5, 11])
let flowing = forward.ingest(heard("O God my God that is me detached"), isFinal: true)
check("a skipped word is not reclaimed from speech that progressed",
      !flowing.contains(.matched(index: 5)), "\(flowing)")

print("\nEvery settled utterance while a word is owed is recorded as a try")
var tried = RecitationMatcher(words: words, hiddenIndices: [1, 3, 6])
_ = tried.ingest(heard("O"), isFinal: true)
_ = tried.ingest(heard("banana"), isFinal: true)
_ = tried.ingest(heard("banana bread"), isFinal: true)
check("a try per utterance", tried.tries.count == 3, "\(tried.tries)")
check("each try names the word that was owed", tried.tries.map(\.wordIndex) == [1, 1, 1],
      "\(tried.tries.map(\.wordIndex))")
check("only the tokens settled since the last try are attributed",
      tried.tries.map(\.heard) == ["O", "banana", "banana bread"], "\(tried.tries.map(\.heard))")
check("none of them were accepted", tried.tries.allSatisfy { !$0.accepted }, "\(tried.tries)")

print("\nSaying the word right after failed tries marks the try accepted")
var eventually = RecitationMatcher(words: words, hiddenIndices: [1, 3, 6])
_ = eventually.ingest(heard("banana"), isFinal: true)
_ = eventually.ingest(heard("Son"), isFinal: true)
check("the last try was accepted", eventually.tries.last?.accepted == true, "\(eventually.tries)")
check("the earlier try stays rejected", eventually.tries.first?.accepted == false,
      "\(eventually.tries)")

print("\nLow-confidence junk does not manufacture a try")
var quiet = RecitationMatcher(words: words, hiddenIndices: [1, 3, 6])
_ = quiet.ingest(heard(".", confidence: 0.0), isFinal: true)
check("no try from a zero-confidence token", quiet.tries.isEmpty, "\(quiet.tries)")

print("\nVolatile text never records a try")
var unsettledTries = RecitationMatcher(words: words, hiddenIndices: [1, 3, 6])
_ = unsettledTries.ingest(heard("O banana"), isFinal: false)
check("no try while volatile", unsettledTries.tries.isEmpty, "\(unsettledTries.tries)")

print("\nRevealing an owed word after failed tries records it")
var revealed = RecitationMatcher(words: words, hiddenIndices: [1, 3, 6])
_ = revealed.ingest(heard("O"), isFinal: true)
_ = revealed.ingest(heard("banana"), isFinal: true)
revealed.replaceHidden(with: [3, 6])
check("the revealed word is recorded", revealed.misses.map(\.wordIndex) == [1], "\(revealed.misses)")
check("recorded as revealed", revealed.misses.first?.outcome == .revealed, "\(revealed.misses)")
check("what was said before revealing is kept",
      revealed.misses.first?.heard.contains("banana") == true, "\(revealed.misses)")

print("\nHiding more words does not manufacture a reveal")
var extended = RecitationMatcher(words: words, hiddenIndices: [1])
_ = extended.ingest(heard("O Son"), isFinal: true)
extended.replaceHidden(with: [3, 6])
check("a matched word leaving the hidden set is not a miss", extended.misses.isEmpty,
      "\(extended.misses)")

print("\nStopping while a word is still owed records it")
var abandoned = RecitationMatcher(words: words, hiddenIndices: [1, 3, 6])
_ = abandoned.ingest(heard("O"), isFinal: true)
_ = abandoned.ingest(heard("banana"), isFinal: true)
abandoned.finish()
check("the owed word is recorded", abandoned.misses.map(\.wordIndex) == [1], "\(abandoned.misses)")
check("recorded as abandoned", abandoned.misses.first?.outcome == .abandoned, "\(abandoned.misses)")

print("\nStopping without ever trying records nothing")
var untouched = RecitationMatcher(words: words, hiddenIndices: [1, 3, 6])
untouched.finish()
check("silence is not a miss", untouched.misses.isEmpty, "\(untouched.misses)")

print("\nA stalled attempt is no longer an empty draft")
var salvaged = RecitationMatcher(words: words, hiddenIndices: [1, 3, 6])
_ = salvaged.ingest(heard("banana"), isFinal: true)
salvaged.finish()
let salvagedDraft = RecitationDraft(
    expectedCount: salvaged.expectedCount,
    matchedCount: salvaged.matchedCount,
    misses: salvaged.misses,
    tries: salvaged.tries,
    transcript: salvaged.transcript
)
check("the attempt survives to the log", !salvagedDraft.isEmpty, "\(salvagedDraft)")

print("\nThe log groups tries and the verdict under each word")
let review = salvagedDraft
    .attempt(chunkID: UUID(), passageTitle: "Hidden Words", excerpt: "O Son of Spirit")
    .wordReviews
check("one word reviewed", review.count == 1, "\(review)")
check("its tries are attached", review.first?.tries.count == 1, "\(review)")
check("its verdict is named", review.first?.verdict == RecitationOutcome.abandoned.label,
      "\(String(describing: review.first?.verdict))")

print("\nBurnt words still carry their outcome")
check("a stalled-out word is exhausted", stalled.misses.first?.outcome == .exhausted,
      "\(stalled.misses)")

print("\nA clean recitation writes nothing down")
var spotless = RecitationMatcher(words: words, hiddenIndices: [1, 3, 6])
_ = spotless.ingest(heard(line), isFinal: true)
check("no tries recorded when nothing went wrong", spotless.tries.isEmpty, "\(spotless.tries)")
check("no misses either", spotless.misses.isEmpty, "\(spotless.misses)")

print("\nThe try that finally lands is kept, because the word had failed before")
var landed = RecitationMatcher(words: words, hiddenIndices: [1, 3, 6])
_ = landed.ingest(heard("banana"), isFinal: true)
_ = landed.ingest(heard("Son"), isFinal: true)
check("the failed try and the one that took are both kept", landed.tries.count == 2,
      "\(landed.tries)")
check("the last one is marked accepted", landed.tries.last?.accepted == true, "\(landed.tries)")
let landedAttempt = RecitationDraft(
    expectedCount: landed.expectedCount,
    matchedCount: landed.matchedCount,
    misses: landed.misses,
    tries: landed.tries,
    transcript: landed.transcript
).attempt(chunkID: UUID(), passageTitle: "Hidden Words", excerpt: "O Son of Spirit")
check("a word retried then matched still counts as a retry",
      landedAttempt.wordReviews(matching: [.retries]).map(\.wordIndex) == [1],
      "\(landedAttempt.wordReviews(matching: [.retries]).map(\.wordIndex))")
check("and it is not a miss", landedAttempt.wordReviews(matching: [.misses]).isEmpty,
      "\(landedAttempt.wordReviews(matching: [.misses]).map(\.wordIndex))")
check("its verdict says it landed in the end",
      landedAttempt.wordReviews.first?.verdict == "matched",
      "\(String(describing: landedAttempt.wordReviews.first?.verdict))")

print("\nThe two filters sort each word into the right bucket")
var sorted = RecitationMatcher(words: words, hiddenIndices: [1, 3, 6])
_ = sorted.ingest(heard("O"), isFinal: true)
for _ in 0..<3 { _ = sorted.ingest(heard("banana"), isFinal: true) }
_ = sorted.ingest(heard("banana of Spirit My first counsel"), isFinal: true)
let sortedAttempt = RecitationDraft(
    expectedCount: sorted.expectedCount,
    matchedCount: sorted.matchedCount,
    misses: sorted.misses,
    tries: sorted.tries,
    transcript: sorted.transcript
).attempt(chunkID: UUID(), passageTitle: "Hidden Words", excerpt: "O Son of Spirit")
check("only the troubled word is reviewed", sortedAttempt.wordReviews.map(\.wordIndex) == [1],
      "\(sortedAttempt.wordReviews.map(\.wordIndex))")
check("the burnt word is a miss",
      sortedAttempt.wordReviews(matching: [.misses]).map(\.wordIndex) == [1],
      "\(sortedAttempt.wordReviews(matching: [.misses]).map(\.wordIndex))")
check("the word said in vain is a retry",
      sortedAttempt.wordReviews(matching: [.retries]).map(\.wordIndex) == [1],
      "\(sortedAttempt.wordReviews(matching: [.retries]).map(\.wordIndex))")
check("no filter shows everything",
      sortedAttempt.wordReviews(matching: []).map(\.wordIndex) == [1],
      "\(sortedAttempt.wordReviews(matching: []).map(\.wordIndex))")
check("a word said in vain is not a skip",
      sortedAttempt.wordReviews(matching: [.skipped]).isEmpty,
      "\(sortedAttempt.wordReviews(matching: [.skipped]).map(\.wordIndex))")

print("\nA miss was said and refused; a skip was never said at all")
func miss(
    _ index: Int,
    _ word: String,
    heard: String,
    _ outcome: RecitationOutcome
) -> RecitationMiss {
    RecitationMiss(
        wordIndex: index,
        expected: word,
        heard: heard,
        expectedKey: PhoneticKey.encode(word),
        heardKeys: heard.isEmpty ? [] : [PhoneticKey.encode(heard)],
        outcome: outcome
    )
}
func attempt(misses: [RecitationMiss], tries: [RecitationTry] = []) -> RecitationAttempt {
    RecitationAttempt(
        chunkID: UUID(),
        passageTitle: "Hidden Words",
        excerpt: "O Son of Spirit",
        expectedCount: misses.count,
        matchedCount: 0,
        misses: misses,
        tries: tries,
        transcript: ""
    )
}
let split = attempt(misses: [
    miss(1, "Son", heard: "banana", .skipped),
    miss(3, "Spirit", heard: "", .skipped),
    miss(6, "counsel", heard: "", .revealed),
    miss(8, "is", heard: "sun", .exhausted),
])
check("words heard wrong are misses",
      split.wordReviews(matching: [.misses]).map(\.wordIndex) == [1, 8],
      "\(split.wordReviews(matching: [.misses]).map(\.wordIndex))")
check("words never voiced are skips",
      split.wordReviews(matching: [.skipped]).map(\.wordIndex) == [3, 6],
      "\(split.wordReviews(matching: [.skipped]).map(\.wordIndex))")
check("the two buckets do not overlap",
      Set(split.wordReviews(matching: [.misses]).map(\.wordIndex))
        .isDisjoint(with: split.wordReviews(matching: [.skipped]).map(\.wordIndex)),
      "\(split.wordReviews.map { "\($0.wordIndex):\($0.isMiss)/\($0.isSkipped)" })")
check("together they account for every failed word",
      split.wordReviews(matching: [.misses, .skipped]).map(\.wordIndex) == [1, 3, 6, 8],
      "\(split.wordReviews(matching: [.misses, .skipped]).map(\.wordIndex))")

print("\nA word that was tried counts as voiced even if nothing was heard for it")
let voiced = attempt(
    misses: [miss(1, "Son", heard: "", .abandoned)],
    tries: [
        RecitationTry(
            wordIndex: 1,
            expected: "Son",
            heard: "banana",
            expectedKey: PhoneticKey.encode("Son"),
            heardKeys: [PhoneticKey.encode("banana")],
            accepted: false
        )
    ]
)
check("having tried it makes it a miss, not a skip",
      voiced.wordReviews(matching: [.misses]).map(\.wordIndex) == [1],
      "\(voiced.wordReviews(matching: [.misses]).map(\.wordIndex))")
check("and it is not counted as skipped", voiced.wordReviews(matching: [.skipped]).isEmpty,
      "\(voiced.wordReviews(matching: [.skipped]).map(\.wordIndex))")
check("it is a retry too", voiced.wordReviews(matching: [.retries]).map(\.wordIndex) == [1],
      "\(voiced.wordReviews(matching: [.retries]).map(\.wordIndex))")

print("\nA word revealed or given up on is not a skip")
var burnt = RecitationMatcher(words: words, hiddenIndices: [1, 3, 6])
_ = burnt.ingest(heard("O"), isFinal: true)
for _ in 0..<3 { _ = burnt.ingest(heard("banana"), isFinal: true) }
check("giving up is its own outcome", burnt.misses.first?.outcome == .exhausted,
      "\(burnt.misses)")
var handed = RecitationMatcher(words: words, hiddenIndices: [1, 3, 6])
_ = handed.ingest(heard("O"), isFinal: true)
_ = handed.ingest(heard("banana"), isFinal: true)
handed.replaceHidden(with: [3, 6])
check("revealing is its own outcome", handed.misses.first?.outcome == .revealed,
      "\(handed.misses)")
check("matched words are never written down",
      sortedAttempt.wordReviews.allSatisfy { $0.isMiss || $0.isRetried },
      "\(sortedAttempt.wordReviews.map(\.wordIndex))")

print("\nTranscript and counts survive for the log")
check("transcript is the spoken text", recorded.transcript == "O banana of Spirit My first counsel",
      recorded.transcript)
check("counts add up", recorded.matchedCount == 2 && recorded.expectedCount == 3,
      "\(recorded.matchedCount)/\(recorded.expectedCount)")

print(failures == 0 ? "\nALL PASS" : "\n\(failures) FAILURE(S)")
exit(failures == 0 ? 0 : 1)
