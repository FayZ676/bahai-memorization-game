import Foundation

var failures = 0
func check(_ label: String, _ condition: Bool, _ detail: @autoclosure () -> String = "") {
    if condition { print("  ok   \(label)") }
    else { failures += 1; print("  FAIL \(label) \(detail())") }
}

print("PhoneticKey equivalences")
for (a, b) in [("Thy", "the"), ("Thee", "the"), ("Thou", "though"), ("hath", "has"), ("art", "are"), ("unto", "into")] {
    check("\(a) ~ \(b)", PhoneticKey.matches(PhoneticKey.encode(b), PhoneticKey.encode(a)),
          "[\(PhoneticKey.encode(a)) vs \(PhoneticKey.encode(b))]")
}
print("PhoneticKey separations")
for (a, b) in [("God", "Lord"), ("Son", "Spirit"), ("mercy", "bounty"), ("light", "night")] {
    check("\(a) != \(b)", !PhoneticKey.matches(PhoneticKey.encode(b), PhoneticKey.encode(a)),
          "[\(PhoneticKey.encode(a)) vs \(PhoneticKey.encode(b))]")
}

func tokens(_ text: String, from: Double = 0, gap: Double = 0.1, confidence: Double = 0.9) -> [RecitationMatcher.HeardToken] {
    var result: [RecitationMatcher.HeardToken] = []
    var clock = from
    for word in text.split(separator: " ") {
        result.append(.init(text: word, confidence: confidence, start: clock, end: clock + 0.3))
        clock += 0.3 + gap
    }
    return result
}

let line = "O Son of Spirit My first counsel is this"
let words = line.split(separator: " ").map(String.init)

print("\nClean recitation at speed (one settled utterance)")
var clean = RecitationMatcher(words: words, hiddenIndices: [1, 3, 6])
let cleanEvents = clean.ingest(tokens(line), finalizedThrough: .greatestFiniteMagnitude)
check("all three matched", cleanEvents == [.matched(index: 1), .matched(index: 3), .matched(index: 6)], "\(cleanEvents)")
check("complete", clean.isComplete)

print("\nASR returns 'the' for 'Thy'")
let thy = ["Thy", "loving", "kindness", "hath", "encompassed", "me"]
var thyMatcher = RecitationMatcher(words: thy, hiddenIndices: [0, 3])
let thyEvents = thyMatcher.ingest(tokens("the loving kindness has encompassed me"), finalizedThrough: .greatestFiniteMagnitude)
check("Thy and hath matched", thyEvents == [.matched(index: 0), .matched(index: 3)], "\(thyEvents)")

print("\nFumble then speak straight past it")
var past = RecitationMatcher(words: words, hiddenIndices: [1, 3, 6])
let pastEvents = past.ingest(tokens("O banana of Spirit My first counsel"), finalizedThrough: .greatestFiniteMagnitude)
check("word 1 missed as moved-on, later words still matched",
      pastEvents == [.missed(index: 1, movedOn: true), .matched(index: 3), .matched(index: 6)], "\(pastEvents)")

print("\nStall and retry: three settled wrong utterances")
var retry = RecitationMatcher(words: words, hiddenIndices: [1, 3, 6])
_ = retry.ingest(tokens("O"), finalizedThrough: .greatestFiniteMagnitude)
var attemptEvents: [RecitationMatcher.Event] = []
var clock = 5.0
for _ in 0..<3 {
    attemptEvents += retry.ingest(tokens("banana", from: clock), finalizedThrough: .greatestFiniteMagnitude)
    clock += 5.0
}
check("two soft misses then a moved-on miss",
      attemptEvents == [.missed(index: 1, movedOn: false), .missed(index: 1, movedOn: false), .missed(index: 1, movedOn: true)],
      "\(attemptEvents)")
check("cursor advanced past the burnt word", retry.nextExpectedIndex == 3, "\(String(describing: retry.nextExpectedIndex))")

print("\nVolatile text never commits a miss")
var volatileMatcher = RecitationMatcher(words: words, hiddenIndices: [1, 3, 6])
let volatileEvents = volatileMatcher.ingest(tokens("O banana"), finalizedThrough: 0)
check("no miss emitted while unsettled", !volatileEvents.contains { if case .missed = $0 { return true }; return false }, "\(volatileEvents)")

print("\nRepeated volatile deliveries are idempotent")
var repeated = RecitationMatcher(words: words, hiddenIndices: [1, 3, 6])
var all: [RecitationMatcher.Event] = []
all += repeated.ingest(tokens("O Son"), finalizedThrough: .greatestFiniteMagnitude)
all += repeated.ingest(tokens("O Son of"), finalizedThrough: .greatestFiniteMagnitude)
all += repeated.ingest(tokens("O Son of Spirit"), finalizedThrough: .greatestFiniteMagnitude)
check("word 1 matched exactly once", all.filter { $0 == .matched(index: 1) }.count == 1, "\(all)")
check("word 3 matched exactly once", all.filter { $0 == .matched(index: 3) }.count == 1, "\(all)")

print(failures == 0 ? "\nALL PASS" : "\n\(failures) FAILURE(S)")
exit(failures == 0 ? 0 : 1)
