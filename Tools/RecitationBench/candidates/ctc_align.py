import argparse
import glob
import json
import os

import numpy as np
import soundfile as sf
import torch
import torchaudio

NEG = -1e30


def load_model(name, quantize=False):
    bundle = getattr(torchaudio.pipelines, name)
    model = bundle.get_model().eval()
    if quantize:
        torch.backends.quantized.engine = "qnnpack"
        model = torch.ao.quantization.quantize_dynamic(model, {torch.nn.Linear}, dtype=torch.qint8)
    labels = bundle.get_labels()
    return model, labels


def emissions(model, path):
    audio, rate = sf.read(path, dtype="float32")
    assert rate == 16000
    with torch.inference_mode():
        logits, _ = model(torch.from_numpy(audio)[None])
    return torch.log_softmax(logits[0], dim=-1).numpy()


HOP = 16000


def frame_count(samples):
    return max(0, (samples - 400) // 320 + 1)


def streamed_hops(model, path, window_seconds, right_seconds):
    audio, rate = sf.read(path, dtype="float32")
    assert rate == 16000
    window = int(window_seconds * 16000)
    right = int(right_seconds * 16000)
    total = frame_count(len(audio))
    padded = np.concatenate([audio, np.zeros(window, np.float32)])
    frames = np.zeros((0, 0), np.float32)
    heard = 0
    while True:
        heard += HOP
        end = min(heard, len(audio) + right)
        start = max(0, end - window)
        chunk = padded[start:start + window]
        with torch.inference_mode():
            logits, _ = model(torch.from_numpy(chunk)[None])
        lp = torch.log_softmax(logits[0], dim=-1).numpy()
        ready = min(total, frame_count(end - right)) if heard < len(audio) + right else total
        first = start // 320
        if frames.size == 0:
            frames = np.zeros((total, lp.shape[1]), np.float32)
        refresh_from = first if start == 0 else max(first, frame_count(end - right - HOP))
        for index in range(refresh_from, ready):
            frames[index] = lp[index - first]
        yield frames[:ready].copy(), ready >= total
        if ready >= total:
            return


def streamed_emissions(model, path, window_seconds, right_seconds):
    for frames, done in streamed_hops(model, path, window_seconds, right_seconds):
        if done:
            return frames


def word_tokens(word, index):
    return [index[c] for c in word.upper() if c in index]


def letter_tokenizer(labels):
    index = {c: i for i, c in enumerate(labels) if c not in "-|"}
    return lambda word: word_tokens(word, index)


class Aligner:
    def __init__(self, words, labels, garbage, skip, edge, restart, final=True, tokenize=None, blanks=(0, 1), frame_seconds=0.02, flat_start=None):
        tokenize = tokenize or letter_tokenizer(labels)
        self.blanks = list(blanks)
        self.frame_seconds = frame_seconds
        self.words = words
        self.recitable = [i for i, w in enumerate(words) if tokenize(w)]
        self.tokenized = [tokenize(words[i]) for i in self.recitable]
        self.garbage = garbage
        self.skip = skip
        self.edge = edge
        self.restart = restart
        self.final = final
        self.flat_start = flat_start
        token, word_of, first, allow2, last_states = [], [], [], [], []
        for w, i in enumerate(self.recitable):
            chars = self.tokenized[w]
            start = len(token)
            first.append(start)
            for k in range(2 * len(chars) + 1):
                token.append(-1 if k % 2 == 0 else chars[k // 2])
                word_of.append(w)
                allow2.append(k % 2 == 1 and k >= 3 and chars[k // 2] != chars[k // 2 - 1])
            last_states.append((len(token) - 2, len(token) - 1))
        self.token = np.array(token)
        self.word_of = np.array(word_of)
        self.first = np.array(first)
        self.allow2 = np.array(allow2)
        self.last = np.array(last_states)
        self.is_first = np.zeros(len(token), bool)
        self.is_first[self.first] = True
        self.is_second = np.zeros(len(token), bool)
        self.is_second[self.first + 1] = True

    def align(self, lp, forbid=None):
        T = lp.shape[0]
        W = len(self.recitable)
        N = len(self.token)
        blank = np.logaddexp.reduce(lp[:, self.blanks], axis=1)
        frame_best = np.maximum(lp.max(axis=1), blank)
        emit = np.where(self.token[None, :] < 0, blank[:, None], lp[:, np.maximum(self.token, 0)])
        if forbid:
            emit = emit.copy()
            emit[:, np.isin(self.word_of, list(forbid))] = NEG
        gemit = frame_best - self.garbage

        delta = np.full(N, NEG)
        G = np.full(W + 1, NEG)
        code = np.zeros((T, N), np.int8)
        entry_src = np.zeros((T, W), np.int32)
        a_from = np.zeros((T, W + 1), np.int8)
        x_state = np.zeros((T, W), np.int32)
        g_from_x = np.zeros((T, W + 1), np.int8)

        for t in range(T):
            if t == 0:
                X = np.full(W, NEG)
                A = np.full(W + 1, NEG)
                A[0] = 0.0
                lead = -self.edge * np.arange(W)
                if self.flat_start is not None:
                    lead = np.full(W, -self.flat_start)
                    lead[0] = 0.0
                xs = self.last[:, 0]
                af = np.ones(W + 1, np.int8)
            else:
                pair = delta[self.last]
                which = pair.argmax(axis=1)
                X = pair.max(axis=1)
                xs = self.last[np.arange(W), which]
                A = np.concatenate([[G[0]], np.maximum(X, G[1:])])
                af = np.concatenate([[1], (G[1:] >= X).astype(np.int8)])
            R = np.empty(W)
            src = np.empty(W, np.int32)
            run, run_src = NEG, 0
            for j in range(W):
                if A[j] >= run - self.skip:
                    run, run_src = A[j], j
                else:
                    run -= self.skip
                R[j] = run
                src[j] = run_src
            if t == 0:
                R = lead
                src[:] = 0
            else:
                back = np.full(W, NEG)
                back_src = np.zeros(W, np.int32)
                for j in range(W - 1, -1, -1):
                    later = back[j + 1] if j + 1 < W else NEG
                    if A[j + 1] >= later:
                        back[j], back_src[j] = A[j + 1], j + 1
                    else:
                        back[j], back_src[j] = later, back_src[j + 1]
                back = back - self.restart
                use = back > R
                R = np.where(use, back, R)
                src = np.where(use, back_src, src)

            stay = delta
            adv1 = np.concatenate([[NEG], delta[:-1]])
            adv1[self.is_first] = NEG
            adv2 = np.concatenate([[NEG, NEG], delta[:-2]])
            adv2[~self.allow2] = NEG
            cand = np.stack([stay, adv1, adv2])
            best_code = cand.argmax(axis=0).astype(np.int8)
            best = cand.max(axis=0)
            entry = R[self.word_of]
            entering = (self.is_first | self.is_second) & (entry > best)
            best = np.where(entering, entry, best)
            best_code = np.where(entering, 3, best_code)

            g_stay = G
            g_x = np.concatenate([[NEG], X])
            if t == 0:
                g_x[0] = 0.0
            G = gemit[t] + np.maximum(g_stay, g_x)
            g_from_x[t] = (g_x > g_stay).astype(np.int8)
            delta = best + emit[t]
            code[t] = best_code
            entry_src[t] = src
            a_from[t] = af
            x_state[t] = xs

        pair = delta[self.last]
        X = pair.max(axis=1)
        final = np.concatenate([[G[0]], np.maximum(X, G[1:])])
        tail = final - (self.skip if self.final else 0.0) * (W - np.arange(W + 1))
        end = int(tail.argmax())
        self.score = float(tail[end])

        frames = {w: [] for w in range(W)}
        t = T - 1
        if end == 0 or G[end] >= (X[end - 1] if end > 0 else NEG):
            state = ("G", end)
        else:
            state = ("S", int(self.last[end - 1][pair[end - 1].argmax()]))
        path_lp = np.zeros(T)
        while t >= 0:
            kind, s = state
            if kind == "S":
                frames[self.word_of[s]].append((t, s))
                path_lp[t] = emit[t, s]
                c = code[t, s]
                if c == 0:
                    state = ("S", s)
                elif c == 1:
                    state = ("S", s - 1)
                elif c == 2:
                    state = ("S", s - 2)
                else:
                    i = entry_src[t, self.word_of[s]]
                    if t == 0:
                        break
                    state = ("G", i) if a_from[t, i] or i == 0 else ("S", int(x_state[t, i - 1]))
            else:
                path_lp[t] = gemit[t]
                if t == 0:
                    break
                if g_from_x[t, s]:
                    state = ("S", int(x_state[t, s - 1])) if s > 0 else ("G", 0)
                t -= 1
                continue
            t -= 1

        result = {}
        for w, i in enumerate(self.recitable):
            assigned = sorted(frames[w])
            segments, current = [], []
            for t, s in assigned:
                if current and t != current[-1][0] + 1:
                    segments.append(current)
                    current = []
                current.append((t, s))
            if current:
                segments.append(current)
            best = None
            for segment in segments:
                chars = [(t, s) for t, s in segment if self.token[s] >= 0]
                if not chars:
                    continue
                lo, hi = chars[0][0], chars[-1][0]
                span = [(t, s) for t, s in segment if lo <= t <= hi]
                mean = float(np.mean([emit[t, s] - frame_best[t] for t, s in span]))
                per_char = {}
                for t, s in chars:
                    per_char.setdefault(s, []).append(emit[t, s] - frame_best[t])
                worst = float(min(np.mean(v) for v in per_char.values()))
                letters = {s for _, s in chars}
                expected = set(range(self.first[w] + 1, self.first[w] + 1 + 2 * len(self.tokenized[w]), 2))
                if letters != expected:
                    worst = float("-inf")
                candidate = {"gop": mean, "worst": worst, "start": lo * self.frame_seconds, "end": (hi + 1) * self.frame_seconds}
                if best is None or candidate["worst"] > best["worst"]:
                    best = candidate
            result[i] = best
        return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("takes")
    parser.add_argument("--model", default="WAV2VEC2_ASR_BASE_960H")
    parser.add_argument("--garbage", type=float, default=2.0)
    parser.add_argument("--skip", type=float, default=20.0)
    parser.add_argument("--edge", type=float, default=0.5)
    parser.add_argument("--restart", type=float, default=10.0)
    parser.add_argument("--out", required=True)
    parser.add_argument("--int8", action="store_true")
    parser.add_argument("--stream", action="store_true")
    parser.add_argument("--window", type=float, default=4.0)
    parser.add_argument("--right", type=float, default=0.5)
    parser.add_argument("--prayer", default=None)
    parser.add_argument("--live", action="store_true")
    parser.add_argument("--guard", type=float, default=0.2)
    parser.add_argument("--confirm", type=int, default=2)
    parser.add_argument("--threshold", type=float, default=-5.0)
    args = parser.parse_args()
    model, labels = load_model(args.model, args.int8)
    output = {}
    for meta in sorted(glob.glob(os.path.join(args.takes, "bench-*.json"))):
        if meta.endswith(".apple.json"):
            continue
        take = json.load(open(meta))
        if args.prayer and take["prayer"] != args.prayer:
            continue
        if args.live:
            words = {}
            for frames, done in streamed_hops(model, meta[:-5] + ".wav", args.window, args.right):
                aligner = Aligner(take["words"], labels, args.garbage, args.skip, args.edge, args.restart, final=done)
                limit = len(frames) * 0.02 - (0 if done else args.guard)
                now = len(frames) * 0.02 + args.right
                aligned = aligner.align(frames)
                order = sorted(aligned)
                for position, index in enumerate(order):
                    value = aligned[index]
                    words.setdefault(index, None)
                    if value is None or value["end"] > limit or value["worst"] < args.threshold:
                        continue
                    following = [aligned[i] for i in order[position + 1:position + 1 + args.confirm]]
                    confirmed = done or (
                        len(following) == args.confirm
                        and all(f is not None and f["worst"] >= args.threshold and f["end"] <= limit for f in following)
                    )
                    if confirmed and words[index] is None:
                        words[index] = dict(value, credited_at=now)
            lp = frames
        else:
            if args.stream:
                lp = streamed_emissions(model, meta[:-5] + ".wav", args.window, args.right)
            else:
                lp = emissions(model, meta[:-5] + ".wav")
            aligner = Aligner(take["words"], labels, args.garbage, args.skip, args.edge, args.restart)
            words = aligner.align(lp)
        greedy = []
        previous = None
        for v in lp.argmax(axis=1):
            if v != previous and v != 0:
                greedy.append(labels[v])
            previous = v
        output[os.path.basename(meta)[:-5]] = {
            "words": {str(k): v for k, v in words.items()},
            "heard": "".join(greedy).replace("|", " ").strip(),
        }
        print(os.path.basename(meta), flush=True)
    json.dump(output, open(args.out, "w"), indent=1)


if __name__ == "__main__":
    main()
