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

print(failures == 0 ? "\nALL PASS" : "\n\(failures) FAILURE(S)")
exit(failures == 0 ? 0 : 1)
