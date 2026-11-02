import argparse
import os

import numpy as np
import onnx
import onnxruntime as ort
import soundfile as sf
import torch
from onnx import TensorProto, helper, numpy_helper

from coreml_convert import WINDOW, Frontend, Recognizer, freeze_positions, reference
from nemo_align import load


def halve_weights(source, target):
    original = onnx.load(source)
    graph = original.graph
    kept, casts = [], []
    for weight in graph.initializer:
        if weight.data_type != TensorProto.FLOAT or np.prod(weight.dims) < 1024:
            kept.append(weight)
            continue
        half = numpy_helper.from_array(numpy_helper.to_array(weight).astype(np.float16), weight.name + "_half")
        kept.append(half)
        casts.append(helper.make_node("Cast", [half.name], [weight.name], to=TensorProto.FLOAT))
    del graph.initializer[:]
    graph.initializer.extend(kept)
    nodes = casts + list(graph.node)
    del graph.node[:]
    graph.node.extend(nodes)
    model = helper.make_model(graph, opset_imports=original.opset_import, ir_version=original.ir_version)
    onnx.save(model, target)


class Pipeline(torch.nn.Module):
    def __init__(self, frontend, recognizer):
        super().__init__()
        self.frontend = frontend
        self.recognizer = recognizer

    def forward(self, audio):
        return self.recognizer(self.frontend(audio))


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
    pipeline = Pipeline(Frontend(model.preprocessor.featurizer, WINDOW), Recognizer(model, valid, frames)).eval()
    example = torch.from_numpy(chunk)[None]

    os.makedirs(args.out, exist_ok=True)
    full = os.path.join(args.out, "conformer-fp32.onnx")
    with torch.inference_mode():
        torch.onnx.export(
            pipeline, example, full,
            input_names=["audio"], output_names=["log_probs"],
            opset_version=17, dynamo=False,
        )
    onnx.checker.check_model(full)
    halved = os.path.join(args.out, "conformer.onnx")
    halve_weights(full, halved)

    for path in [full, halved]:
        session = ort.InferenceSession(path, providers=["CPUExecutionProvider"])
        print(f"{os.path.basename(path)}: {os.path.getsize(path) / 1e6:.1f} MB")
        for label, window, expected in [("speech", chunk, log_probs), ("quiet", quiet, quiet_log_probs)]:
            predicted = session.run(["log_probs"], {"audio": window[None]})[0][0]
            gap = np.abs(np.exp(predicted) - np.exp(expected[0].numpy())).sum(axis=1) / 2
            print(f"  {label:6} shape {predicted.shape} nan {int(np.isnan(predicted).sum())} "
                  f"mass moved per frame mean {np.nanmean(gap):.4f} max {np.nanmax(gap):.4f}")


if __name__ == "__main__":
    main()
