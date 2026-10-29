import argparse
import json
import re

from sentencepiece import sentencepiece_model_pb2

from nemo_align import load, tokenizer


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", default="stt_en_conformer_ctc_medium")
    parser.add_argument("--out", required=True)
    parser.add_argument("--reference", default=None)
    parser.add_argument("--words-from", default=None)
    args = parser.parse_args()
    model = load(args.model)
    proto = sentencepiece_model_pb2.ModelProto()
    proto.ParseFromString(model.tokenizer.tokenizer.serialized_model_proto())
    json.dump({
        "blank": model.decoder.num_classes_with_blank - 1,
        "pieces": [p.piece for p in proto.pieces],
        "scores": [p.score for p in proto.pieces],
    }, open(args.out, "w"), ensure_ascii=False)
    if args.reference and args.words_from:
        tokenize = tokenizer(model)
        words = sorted(set(re.findall(r"\S+", open(args.words_from, encoding="utf-8").read())))
        json.dump({w: tokenize(w) for w in words}, open(args.reference, "w"), ensure_ascii=False)
        print(f"{len(words)} reference words")


if __name__ == "__main__":
    main()
