import argparse
import math
import os
import shutil
import subprocess

import coremltools as ct
import coremltools.optimize.coreml as cto
import numpy as np
import soundfile as sf
import torch

from nemo_align import load

WINDOW = 96000


class Frontend(torch.nn.Module):
    def __init__(self, featurizer, samples):
        super().__init__()
        n_fft = featurizer.n_fft
        window = torch.zeros(n_fft)
        left = (n_fft - featurizer.win_length) // 2
        window[left:left + featurizer.win_length] = featurizer.window.float()
        bins = n_fft // 2 + 1
        n = torch.arange(n_fft, dtype=torch.float64)
        k = torch.arange(bins, dtype=torch.float64)[:, None]
        angle = 2 * math.pi * k * n / n_fft
        basis = torch.cat([torch.cos(angle), -torch.sin(angle)]) * window.double()
        self.register_buffer("basis", basis.float()[:, None, :])
        self.register_buffer("fb", featurizer.fb.float()[0])
        self.hop = featurizer.hop_length
        self.pad = n_fft // 2
        self.bins = bins
        self.preemph = featurizer.preemph
        self.guard = featurizer.log_zero_guard_value_fn(torch.zeros(1))
        self.valid = (samples + 2 * self.pad - n_fft) // self.hop
        self.pad_value = featurizer.pad_value

    def forward(self, audio):
        emphasized = torch.cat([audio[:, :1], audio[:, 1:] - self.preemph * audio[:, :-1]], dim=1)
        padded = torch.nn.functional.pad(emphasized[:, None, :], (self.pad, self.pad))
        spectrum = torch.nn.functional.conv1d(padded, self.basis, stride=self.hop)
        power = spectrum[:, : self.bins] ** 2 + spectrum[:, self.bins:] ** 2
        mel = torch.log(torch.matmul(self.fb, power) + self.guard)
        valid = mel[:, :, : self.valid]
        mean = valid.mean(dim=2, keepdim=True)
        std = torch.sqrt(((valid - mean) ** 2).sum(dim=2, keepdim=True) / (self.valid - 1)) + 1e-5
        normalized = (valid - mean) / std
        tail = torch.full_like(mel[:, :, self.valid:], self.pad_value)
        return torch.cat([normalized, tail], dim=2)


class FrozenPositions(torch.nn.Module):
    def __init__(self, encoding, length):
        super().__init__()
        center = encoding.pe.size(1) // 2 + 1
        self.register_buffer("positions", encoding.pe[:, center - length:center + length - 1].clone())

    def forward(self, x, cache_len=0):
        return x, self.positions


def freeze_positions(model, features):
    lengths = []
    hook = model.encoder.pos_enc.register_forward_hook(lambda module, inputs, output: lengths.append(output[0].size(1)))
    with torch.inference_mode():
        model.encoder(audio_signal=features, length=torch.tensor([features.shape[2] - 1]))
    hook.remove()
    shrink_first_layer(model.encoder.layers[0], 1.0 / (model.encoder.pos_enc.xscale or 1.0))
    model.encoder.pos_enc = FrozenPositions(model.encoder.pos_enc, lengths[0])


def shrink_first_layer(layer, factor):
    with torch.no_grad():
        for projection in [layer.feed_forward1.linear2, layer.self_attn.linear_out, layer.conv.pointwise_conv2, layer.feed_forward2.linear2]:
            projection.weight.mul_(factor)
            if projection.bias is not None:
                projection.bias.mul_(factor)


class Recognizer(torch.nn.Module):
    def __init__(self, model, valid, frames):
        super().__init__()
        self.encoder = model.encoder
        self.decoder = model.decoder
        self.valid = valid
        self.frames = frames

    def forward(self, features):
        encoded, _ = self.encoder(audio_signal=features, length=torch.tensor([self.valid]))
        return self.decoder(encoder_output=encoded)[:, : self.frames]


def reference(model, chunk):
    signal = torch.from_numpy(chunk)[None]
    with torch.inference_mode():
        features, lengths = model.preprocessor(input_signal=signal, length=torch.tensor([signal.shape[1]]))
        log_probs, frames, _ = model.forward(input_signal=signal, input_signal_length=torch.tensor([signal.shape[1]]))
    return features, int(lengths[0]), log_probs[:, : int(frames[0])], int(frames[0])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("takes")
    parser.add_argument("--model", default="stt_en_conformer_ctc_medium")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    model = load(args.model)
    for module in model.modules():
        if hasattr(module, "dropout_rate"):
            module.eval()

    wav = sorted(p for p in os.listdir(args.takes) if p.endswith(".wav"))[0]
    audio, _ = sf.read(os.path.join(args.takes, wav), dtype="float32")
    chunk = np.zeros(WINDOW, np.float32)
    chunk[: min(WINDOW, len(audio))] = audio[:WINDOW]
    quiet = np.zeros(WINDOW, np.float32)
    quiet[:16000] = audio[:16000]
    features, valid, log_probs, frames = reference(model, chunk)
    _, _, quiet_log_probs, _ = reference(model, quiet)

    freeze_positions(model, features)
    frontend = Frontend(model.preprocessor.featurizer, WINDOW).eval()
    recognizer = Recognizer(model, valid, frames).eval()
    example = torch.from_numpy(chunk)[None]
    with torch.inference_mode():
        mine = frontend(example)
        print(f"features: {tuple(features.shape)} vs {tuple(mine.shape)}, max diff {float((features - mine).abs().max()):.2e}")
        mine_lp = recognizer(mine)
        print(f"log probs: {frames} frames, max diff {float((log_probs - mine_lp).abs().max()):.2e}")
        quiet_lp = recognizer(frontend(torch.from_numpy(quiet)[None]))
        print(f"quiet log probs: max diff {float((quiet_log_probs - quiet_lp).abs().max()):.2e}")

    os.makedirs(args.out, exist_ok=True)
    with torch.no_grad():
        traced_frontend = torch.jit.trace(frontend, example)
        traced_recognizer = torch.jit.trace(recognizer, mine)
    front = ct.convert(
        traced_frontend,
        inputs=[ct.TensorType(name="audio", shape=example.shape, dtype=np.float32)],
        outputs=[ct.TensorType(name="features", dtype=np.float32)],
        compute_precision=ct.precision.FLOAT32,
        minimum_deployment_target=ct.target.iOS18,
    )
    back = ct.convert(
        traced_recognizer,
        inputs=[ct.TensorType(name="features", shape=mine.shape, dtype=np.float32)],
        outputs=[ct.TensorType(name="log_probs", dtype=np.float32)],
        compute_precision=ct.precision.FLOAT16,
        minimum_deployment_target=ct.target.iOS18,
    )
    quantized = cto.linear_quantize_weights(
        back, cto.OptimizationConfig(global_config=cto.OpLinearQuantizerConfig(mode="linear_symmetric", dtype="int8"))
    )
    for name, recognizer_model in [("conformer-fp16", back), ("conformer-int8", quantized)]:
        pipeline = ct.utils.make_pipeline(front, recognizer_model)
        package = os.path.join(args.out, f"{name}.mlpackage")
        shutil.rmtree(package, ignore_errors=True)
        shutil.rmtree(os.path.join(args.out, f"{name}.mlmodelc"), ignore_errors=True)
        pipeline.save(package)
        subprocess.run(["xcrun", "coremlcompiler", "compile", package, args.out], check=True, stdout=subprocess.DEVNULL)
        size = subprocess.run(["du", "-sh", os.path.join(args.out, f"{name}.mlmodelc")], capture_output=True, text=True).stdout.split()[0]
        print(f"{name}: {size}")
        for units in ["CPU_ONLY", "CPU_AND_GPU", "CPU_AND_NE"]:
            loaded = ct.models.MLModel(package, compute_units=getattr(ct.ComputeUnit, units))
            for label, audio_window, expected in [("speech", chunk, log_probs), ("quiet", quiet, quiet_log_probs)]:
                predicted = loaded.predict({"audio": audio_window[None]})["log_probs"][0]
                gap = np.abs(np.exp(predicted) - np.exp(expected[0].numpy())).sum(axis=1) / 2
                print(f"  {units:12} {label:6} nan {int(np.isnan(predicted).sum()):6}  min {np.nanmin(predicted):9.1f}  "
                      f"mass moved per frame mean {np.nanmean(gap):.4f} max {np.nanmax(gap):.4f}")


if __name__ == "__main__":
    main()
