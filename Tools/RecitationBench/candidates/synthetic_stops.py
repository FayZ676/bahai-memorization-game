import argparse
import json
import os

import numpy as np
import soundfile as sf

RATE = 16000
QUIET = 4.0


def room_noise(audio, seconds):
    size = RATE // 2
    slices = [audio[i:i + size] for i in range(0, len(audio) - size, size // 2)]
    quietest = min(slices, key=lambda s: float(np.sqrt(np.mean(s ** 2))))
    return np.tile(quietest, int(np.ceil(seconds * RATE / size)))[: int(seconds * RATE)]


def write(out, stem, audio, take, unsaid, card):
    sf.write(os.path.join(out, stem + ".wav"), audio, RATE, subtype="PCM_16")
    json.dump(dict(take, card=card, unsaid=sorted(unsaid), slips=[]), open(os.path.join(out, stem + ".json"), "w"))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("takes")
    parser.add_argument("timings")
    parser.add_argument("out")
    parser.add_argument("--every", type=int, default=3)
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)
    timings = json.load(open(args.timings))
    made = 0
    for stem, output in sorted(timings.items()):
        take = json.load(open(os.path.join(args.takes, stem + ".json")))
        audio, _ = sf.read(os.path.join(args.takes, stem + ".wav"), dtype="float32")
        noise = room_noise(audio, QUIET)
        placed = {int(k): v for k, v in output["words"].items() if v}
        wrong = set(take["unsaid"]) | set(take["slips"])
        recitable = sorted(int(k) for k in output["words"])

        def cut_after(index):
            return int(min(len(audio), (placed[index]["end"] + 0.35) * RATE))

        if take["card"] == "C1":
            for position in range(args.every - 1, len(recitable) - 1, args.every):
                index = recitable[position]
                if index not in placed:
                    continue
                cut = cut_after(index)
                said = {i for i in recitable if i in placed and placed[i]["start"] * RATE < cut}
                write(args.out, f"{stem}-stop{index}", np.concatenate([audio[:cut], noise]), take,
                      set(recitable) - said, "STOP")
                made += 1
            for position in range(4, len(recitable) - 8, 3 * args.every):
                skipped = recitable[position:position + 4]
                kept = recitable[position + 4:position + 6]
                previous = recitable[position - 1]
                if not all(i in placed for i in [previous] + skipped + kept):
                    continue
                gap_from = int((placed[previous]["end"] + 0.35) * RATE)
                gap_to = int(max(placed[skipped[-1]]["end"], placed[kept[0]]["start"] - 0.1) * RATE)
                clip = np.concatenate([audio[:gap_from], noise[: RATE], audio[gap_to:cut_after(kept[-1])], noise])
                kept_until = cut_after(kept[-1])
                said = {i for i in recitable if i in placed and (
                    placed[i]["start"] * RATE < gap_from or gap_to <= placed[i]["start"] * RATE < kept_until)}
                write(args.out, f"{stem}-skip{skipped[0]}", clip, take, set(recitable) - said, "SKIP")
                made += 1
        elif wrong and take["card"].startswith(("S", "FD")):
            first_wrong = min(wrong)
            after = [i for i in recitable if i > first_wrong and i in placed and i not in wrong][:1]
            if not after:
                continue
            cut = cut_after(after[0])
            said = {i for i in recitable if i in placed and placed[i]["start"] * RATE < cut} - wrong
            write(args.out, f"{stem}-wrong{first_wrong}", np.concatenate([audio[:cut], noise]), take,
                  set(recitable) - said, "WRONG")
            made += 1
    print(f"{made} synthetic takes")


if __name__ == "__main__":
    main()
