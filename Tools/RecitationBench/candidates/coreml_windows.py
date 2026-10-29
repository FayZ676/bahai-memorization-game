import argparse
import glob
import json
import os
import time

import coremltools as ct
import numpy as np
import soundfile as sf

WINDOW = 96000
HOP = 16000
LOOKAHEAD = 8000
SAMPLES_PER_FRAME = 640


def replay(model, path):
    audio, rate = sf.read(path, dtype="float32")
    assert rate == 16000
    starts, millis, outputs = [], [], []
    heard = 0
    while True:
        heard += HOP
        end = min(heard, len(audio) + LOOKAHEAD)
        start = max(0, end - WINDOW) // SAMPLES_PER_FRAME * SAMPLES_PER_FRAME
        chunk = np.zeros((1, WINDOW), np.float32)
        heard_audio = audio[start:min(end, len(audio))]
        chunk[0, : len(heard_audio)] = heard_audio
        clock = time.perf_counter()
        log_probs = model.predict({"audio": chunk})["log_probs"][0]
        millis.append((time.perf_counter() - clock) * 1000)
        outputs.append(log_probs.astype(np.float16))
        starts.append(start)
        if heard >= len(audio) + LOOKAHEAD:
            break
    return starts, millis, np.stack(outputs)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("takes")
    parser.add_argument("package")
    parser.add_argument("--out", required=True)
    parser.add_argument("--units", default="ALL")
    args = parser.parse_args()
    name = os.path.basename(args.package).removesuffix(".mlpackage") + "-mac"
    os.makedirs(args.out, exist_ok=True)
    model = ct.models.MLModel(args.package, compute_units=getattr(ct.ComputeUnit, args.units))
    for wav in sorted(glob.glob(os.path.join(args.takes, "bench-*.wav"))):
        starts, millis, outputs = replay(model, wav)
        stem = os.path.join(args.out, os.path.basename(wav)[:-4])
        outputs.tofile(f"{stem}.{name}.f16")
        json.dump({
            "model": name, "computeUnits": args.units, "windows": len(starts), "frames": outputs.shape[1],
            "classes": outputs.shape[2], "starts": starts, "millis": millis, "loadMillis": 0,
        }, open(f"{stem}.{name}.json", "w"))
        print(f"{os.path.basename(stem)} windows={len(starts)} median={np.median(millis):.0f} ms", flush=True)


if __name__ == "__main__":
    main()
