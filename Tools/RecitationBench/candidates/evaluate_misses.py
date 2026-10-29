import argparse
import json
import os


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("takes")
    parser.add_argument("result")
    parser.add_argument("--show", action="store_true")
    args = parser.parse_args()
    result = json.load(open(args.result))
    tally = {"flash wrong": 0, "flash correct, later credited": 0, "flash correct, never credited": 0,
             "moved on wrong": 0, "moved on correct": 0}
    wrong_total = flagged_wrong = 0
    for stem, output in sorted(result.items()):
        take = json.load(open(os.path.join(args.takes, stem + ".json")))
        words = take["words"]
        wrong = set(take["unsaid"]) | set(take["slips"])
        hidden = set(output["hidden"])
        credited = {int(k) for k, v in output["words"].items() if v}
        flagged = set()
        for miss in output["misses"]:
            index = miss["index"]
            flagged.add(index)
            if miss["movedOn"]:
                kind = "moved on wrong" if index in wrong else "moved on correct"
            elif index in wrong:
                kind = "flash wrong"
            else:
                kind = "flash correct, later credited" if index in credited else "flash correct, never credited"
            tally[kind] += 1
            if args.show and "correct" in kind:
                print(f"  {kind:30} {words[index]!r:16} #{index} at {miss['at']:.1f}s  {stem}")
        hidden_wrong = wrong & hidden
        wrong_total += len(hidden_wrong)
        flagged_wrong += len(hidden_wrong & flagged)
    for kind, count in tally.items():
        print(f"{kind:32} {count}")
    print(f"hidden wrong words given any miss signal: {flagged_wrong}/{wrong_total}")


if __name__ == "__main__":
    main()
