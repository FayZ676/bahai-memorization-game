import argparse
import json
import os


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("takes")
    parser.add_argument("result")
    parser.add_argument("--threshold", type=float, default=None)
    parser.add_argument("--score", default="worst")
    args = parser.parse_args()
    result = json.load(open(args.result))

    owed_scores, wrong_scores = [], []
    rows = []
    for stem, output in sorted(result.items()):
        take = json.load(open(os.path.join(args.takes, stem + ".json")))
        words = take["words"]
        wrong = set(take["unsaid"]) | set(take["slips"])
        for key, value in output["words"].items():
            index = int(key)
            score = value[args.score] if value else float("-inf")
            label = "wrong" if index in wrong else "owed"
            (wrong_scores if label == "wrong" else owed_scores).append((score, stem, words[index]))
            rows.append((stem, take["prayer"], take["card"], index, words[index], label, score))

    owed_scores.sort()
    wrong_scores.sort(reverse=True)
    print(f"owed words {len(owed_scores)}, wrong words {len(wrong_scores)}")
    print("lowest-scoring correctly said words:")
    for score, stem, word in owed_scores[:12]:
        print(f"  {score:7.2f}  {word:15} {stem}")
    print("highest-scoring wrong words:")
    for score, stem, word in wrong_scores[:12]:
        print(f"  {score:7.2f}  {word:15} {stem}")
    gap = owed_scores[0][0] - wrong_scores[0][0]
    print(f"separable: {gap > 0}  (lowest owed {owed_scores[0][0]:.2f}, highest wrong {wrong_scores[0][0]:.2f})")

    finite_wrong = [s for s, _, _ in wrong_scores if s > float("-inf")]
    safe = (max(finite_wrong) + 1e-6) if finite_wrong else float("-inf")
    print(f"recall at the strictest threshold that credits no wrong word ({safe:.2f}): "
          f"{sum(s >= safe for s, _, _ in owed_scores)}/{len(owed_scores)}")
    for cut in [-0.5, -1.0, -1.5, -2.0, -3.0, -4.0, -5.0]:
        print(f"  threshold {cut:5.1f}: owed credited {sum(s >= cut for s, _, _ in owed_scores):4}/{len(owed_scores)}, "
              f"wrong credited {sum(s >= cut for s, _, _ in wrong_scores)}/{len(wrong_scores)}")
    threshold = args.threshold
    if threshold is None:
        threshold = (owed_scores[0][0] + wrong_scores[0][0]) / 2 if gap > 0 else safe
    by_prayer = {}
    for stem, prayer, card, index, word, label, score in rows:
        credited = score >= threshold
        totals = by_prayer.setdefault(prayer, {"owed": 0, "credited": 0, "false_pass": 0, "wrong": 0})
        if label == "owed":
            totals["owed"] += 1
            totals["credited"] += credited
        else:
            totals["wrong"] += 1
            totals["false_pass"] += credited
    lags = sorted(
        v["credited_at"] - v["end"]
        for output in result.values() for v in output["words"].values()
        if v and "credited_at" in v and v["worst"] >= threshold
    )
    if lags:
        pick = lambda q: lags[min(len(lags) - 1, int(q * len(lags)))]
        print(f"credit lag after word end: median {pick(0.5):.2f}s, p90 {pick(0.9):.2f}s, max {lags[-1]:.2f}s")
    lags = sorted(
        v["credited_at"] - v["end"]
        for output in result.values() for v in output["words"].values()
        if v and "credited_at" in v and v["worst"] >= threshold
    )
    if lags:
        pick = lambda q: lags[min(len(lags) - 1, int(q * len(lags)))]
        print(f"credit lag after word end: median {pick(0.5):.2f}s, p90 {pick(0.9):.2f}s, max {lags[-1]:.2f}s")
    print(f"\nthreshold {threshold:.2f}")
    for prayer, totals in sorted(by_prayer.items()):
        recall = totals["credited"] / totals["owed"]
        print(f"  {prayer}: {totals['credited']}/{totals['owed']} correct words credited ({recall:.2%}), "
              f"{totals['false_pass']}/{totals['wrong']} wrong words credited")


if __name__ == "__main__":
    main()
