import argparse
import glob
import json
import os
import sys

import numpy as np
import soundfile as sf
import torch

sys.path.insert(0, os.path.dirname(__file__))
from ctc_align import Aligner


def load(name, quantize=False):
    from nemo.collections.asr.models import ASRModel

    model = ASRModel.from_pretrained(name).eval()
    if quantize:
        torch.backends.quantized.engine = "qnnpack"
        torch.ao.quantization.quantize_dynamic(model, {torch.nn.Linear}, dtype=torch.qint8, inplace=True)
    model.preprocessor.featurizer.dither = 0.0
    model.preprocessor.featurizer.pad_to = 0
    return model


def emissions(model, path):
    audio, rate = sf.read(path, dtype="float32")
    assert rate == 16000
    signal = torch.from_numpy(audio)[None]
    with torch.inference_mode():
        log_probs, lengths, _ = model.forward(input_signal=signal, input_signal_length=torch.tensor([signal.shape[1]]))
    return log_probs[0, : int(lengths[0])].numpy()


SAMPLES_PER_FRAME = 640
HOP = 16000


def window_emissions(model, chunk):
    signal = torch.from_numpy(chunk)[None]
    with torch.inference_mode():
        log_probs, lengths, _ = model.forward(input_signal=signal, input_signal_length=torch.tensor([signal.shape[1]]))
    return log_probs[0, : int(lengths[0])].numpy()


def recorded_windows(path, recorded):
    directory, name = recorded
    stem = os.path.join(directory, os.path.basename(path)[:-4])
    report = json.load(open(f"{stem}.{name}.json"))
    raw = np.fromfile(f"{stem}.{name}.f16", dtype=np.float16)
    windows = raw.reshape(report["windows"], report["frames"], report["classes"]).astype(np.float32)
    return iter(zip(report["starts"], windows))


def live_hops(model, path, window_seconds, right_seconds, refresh=False, left_keep=1.0, recorded=None):
    windows = recorded_windows(path, recorded) if recorded else None
    audio, rate = sf.read(path, dtype="float32")
    assert rate == 16000
    total = len(emissions(model, path))
    window = int(window_seconds * 16000)
    right = int(right_seconds * 16000)
    frames = None
    heard = 0
    while True:
        heard += HOP
        end = min(heard, len(audio) + right)
        start = max(0, end - window) // SAMPLES_PER_FRAME * SAMPLES_PER_FRAME
        chunk = np.zeros(window, np.float32)
        heard_audio = audio[start:min(end, len(audio))]
        chunk[:len(heard_audio)] = heard_audio
        if windows is None:
            lp = window_emissions(model, chunk)
        else:
            recorded_start, lp = next(windows)
            assert recorded_start == start, (recorded_start, start)
        if frames is None:
            frames = np.zeros((total, lp.shape[1]), np.float32)
        done = heard >= len(audio) + right
        ready = total if done else min(total, (end - right) // SAMPLES_PER_FRAME)
        first = start // SAMPLES_PER_FRAME
        if refresh:
            refresh_from = first if start == 0 else first + int(left_keep * 16000) // SAMPLES_PER_FRAME
        else:
            refresh_from = first if start == 0 else max(first, (end - right - HOP) // SAMPLES_PER_FRAME)
        for index in range(refresh_from, min(ready, first + len(lp))):
            frames[index] = lp[index - first]
        yield frames[:ready].copy(), end / 16000, done
        if done:
            return


def tokenizer(model):
    def tokenize(word):
        cleaned = "".join(c for c in word.lower() if c.isalpha() or c == "'")
        return model.tokenizer.text_to_ids(cleaned) if cleaned else []

    return tokenize


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("takes")
    parser.add_argument("--model", required=True)
    parser.add_argument("--frame", type=float, default=0.04)
    parser.add_argument("--garbage", type=float, default=2.0)
    parser.add_argument("--skip", type=float, default=20.0)
    parser.add_argument("--edge", type=float, default=0.5)
    parser.add_argument("--restart", type=float, default=10.0)
    parser.add_argument("--out", required=True)
    parser.add_argument("--int8", action="store_true")
    parser.add_argument("--live", action="store_true")
    parser.add_argument("--window", type=float, default=6.0)
    parser.add_argument("--right", type=float, default=1.0)
    parser.add_argument("--guard", type=float, default=0.2)
    parser.add_argument("--confirm", type=int, default=2)
    parser.add_argument("--evidence", type=float, default=None)
    parser.add_argument("--refresh", action="store_true")
    parser.add_argument("--left-keep", type=float, default=1.0)
    parser.add_argument("--flat-start", type=float, default=None)
    parser.add_argument("--divergence", action="store_true")
    parser.add_argument("--threshold", type=float, default=-7.67)
    parser.add_argument("--recorded", nargs=2, metavar=("DIRECTORY", "MODEL"), default=None)
    args = parser.parse_args()
    model = load(args.model, args.int8)
    blank = model.decoder.num_classes_with_blank - 1
    vocabulary = list(model.decoder.vocabulary)
    tokenize = tokenizer(model)
    output = {}
    for meta in sorted(glob.glob(os.path.join(args.takes, "bench-*.json"))):
        if "." in os.path.basename(meta)[:-5]:
            continue
        take = json.load(open(meta))
        make = lambda final: Aligner(
            take["words"], None, args.garbage, args.skip, args.edge, args.restart,
            final=final, tokenize=tokenize, blanks=(blank,), frame_seconds=args.frame, flat_start=args.flat_start,
        )
        if args.divergence:
            whole = emissions(model, meta[:-5] + ".wav")
            for frames, now, done in live_hops(model, meta[:-5] + ".wav", args.window, args.right, args.refresh, args.left_keep, args.recorded):
                pass
            gap = np.abs(np.exp(frames) - np.exp(whole)).sum(axis=1) / 2
            output[os.path.basename(meta)[:-5]] = {"mean": float(gap.mean()), "p99": float(np.percentile(gap, 99))}
            print(os.path.basename(meta), flush=True)
            continue
        if args.live:
            words = {}
            for frames, now, done in live_hops(model, meta[:-5] + ".wav", args.window, args.right, args.refresh, args.left_keep, args.recorded):
                limit = len(frames) * args.frame - (0 if done else args.guard)
                aligner = make(done)
                aligned = aligner.align(frames)
                base = aligner.score
                position_of = {index: w for w, index in enumerate(aligner.recitable)}
                order = sorted(aligned)
                for position, index in enumerate(order):
                    value = aligned[index]
                    words.setdefault(index, None)
                    if words[index] is not None or value is None:
                        continue
                    if value["end"] > limit or value["worst"] < args.threshold:
                        continue
                    if args.evidence is not None:
                        if done:
                            confirmed = True
                        else:
                            aligner.align(frames, forbid={position_of[index]})
                            confirmed = base - aligner.score >= args.evidence
                    else:
                        following = [aligned[i] for i in order[position + 1:position + 1 + args.confirm]]
                        confirmed = done or (
                            len(following) == args.confirm
                            and all(f is not None and f["worst"] >= args.threshold and f["end"] <= limit for f in following)
                        )
                    if confirmed:
                        words[index] = dict(value, credited_at=now)
            lp = frames
        else:
            lp = emissions(model, meta[:-5] + ".wav")
            words = make(True).align(lp)
        greedy, previous = [], None
        for v in lp.argmax(axis=1):
            if v != previous and v != blank:
                greedy.append(vocabulary[int(v)])
            previous = v
        output[os.path.basename(meta)[:-5]] = {
            "words": {str(k): v for k, v in words.items()},
            "heard": "".join(greedy).replace("▁", " ").strip(),
        }
        print(os.path.basename(meta), flush=True)
    json.dump(output, open(args.out, "w"), indent=1)


if __name__ == "__main__":
    main()
