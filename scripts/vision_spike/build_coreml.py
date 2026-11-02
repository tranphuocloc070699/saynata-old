# /// script
# requires-python = ">=3.11,<3.13"
# dependencies = ["torch==2.7.0", "torchvision==0.22.0", "open_clip_torch>=3.1", "timm", "pillow", "nltk",
#                 "scikit-learn", "numpy", "coremltools>=8.3"]
# [tool.uv]
# exclude-newer = "2026-10-31T00:00:00Z"  # same package versions on every run
# [[tool.uv.index]]
# name = "pytorch-cpu"
# url = "https://download.pytorch.org/whl/cpu"
# explicit = true
# [tool.uv.sources]
# torch = { index = "pytorch-cpu" }
# torchvision = { index = "pytorch-cpu" }
# ///
"""Build the camera files the iOS app ships (TASK-121.2): the MobileCLIP image encoder as Core ML, the text
vectors of every label, and the trained food layer.

Run (from the repo root; free, CPU only, about 25 minutes the first time, seconds after that):
  uv run scripts/vision_spike/build_coreml.py --train <30VNFoods/test> [--model MobileCLIP2-S2] [--check <photos dir>]
In a Claude cloud session, put NLTK_ALLOW_PROXIED_URLOPEN=1 before uv.

Writes into EnglishTranslation/EnglishTranslation/Resources/Vision/ (checked into git like dictionary.sqlite):
  MobileCLIPImage.mlpackage  256x256 RGB image in, "embedding" out (512 numbers, length 1). Weights 8-bit.
  labels.json                labels, which ones are food words or dishes, the dish names with accents
  label_vectors.f16          one 512-number text vector per label, float16, little-endian, in labels.json order
  food_layer.json            the trained layer for the 30 dishes (weights 30x512, bias 30)
Safe to run again: it overwrites those files. The 30VNFoods photos are CC BY-NC-SA (TASK-122: retrain before the
App Store). With --check it compares Core ML-style 8-bit weights with PyTorch on a few photos.
"""
import argparse, json, pathlib, random, shutil, sys
import numpy as np, torch, open_clip
from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from clip_test import build_vocab, norm, prompt  # same labels and prompts as the spike  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "EnglishTranslation/EnglishTranslation/Resources/Vision"
FOOD_LEX = {"noun.food"}
# The 30VNFoods folder names, with their Vietnamese spelling (the label the app shows and asks the word API for).
DISHES = {
    "Banh beo": "bánh bèo", "Banh bot loc": "bánh bột lọc", "Banh can": "bánh căn", "Banh canh": "bánh canh",
    "Banh chung": "bánh chưng", "Banh cuon": "bánh cuốn", "Banh duc": "bánh đúc", "Banh gio": "bánh giò",
    "Banh khot": "bánh khọt", "Banh mi": "bánh mì", "Banh pia": "bánh pía", "Banh tet": "bánh tét",
    "Banh trang nuong": "bánh tráng nướng", "Banh xeo": "bánh xèo", "Bun bo Hue": "bún bò huế",
    "Bun dau mam tom": "bún đậu mắm tôm", "Bun mam": "bún mắm", "Bun rieu": "bún riêu",
    "Bun thit nuong": "bún thịt nướng", "Ca kho to": "cá kho tộ", "Canh chua": "canh chua", "Cao lau": "cao lầu",
    "Chao long": "cháo lòng", "Com tam": "cơm tấm", "Goi cuon": "gỏi cuốn", "Hu tieu": "hủ tiếu",
    "Mi quang": "mì quảng", "Nem chua": "nem chua", "Pho": "phở", "Xoi xeo": "xôi xéo",
}


class ImageEncoder(torch.nn.Module):
    """The visual tower plus the length-1 step, so the phone gets a ready vector."""

    def __init__(self, model):
        super().__init__()
        self.model = model

    def forward(self, image):
        return torch.nn.functional.normalize(self.model.encode_image(image), dim=-1)


def food_words(vocab: list[str]) -> set[str]:
    from nltk.corpus import wordnet as wn
    out = set()
    for w in vocab:
        s = wn.synsets(w.replace(" ", "_"), pos=wn.NOUN)
        if s and s[0].lexname() in FOOD_LEX:
            out.add(w)
    return out


def train_food_layer(model, preprocess, train: pathlib.Path, per_class: int, cache: pathlib.Path):
    from sklearn.linear_model import LogisticRegression
    classes = sorted(p.name for p in train.iterdir() if p.is_dir())
    if set(classes) != set(DISHES):
        raise SystemExit(f"{train} must hold the 30 dish folders; unknown: {sorted(set(classes) ^ set(DISHES))}")
    random.seed(0)
    files, labels = [], []
    for ci, c in enumerate(classes):
        fs = sorted((train / c).glob("*.jp*g")) + sorted((train / c).glob("*.png"))
        for f in random.sample(fs, min(per_class, len(fs))):
            files.append(f); labels.append(ci)
    if cache.exists():
        x = np.load(cache)
    else:
        out = []
        with torch.no_grad():
            for i in range(0, len(files), 32):
                batch = torch.stack([preprocess(Image.open(f).convert("RGB")) for f in files[i:i + 32]])
                out.append(torch.nn.functional.normalize(model.encode_image(batch), dim=-1).numpy())
                print(f"  food photos {min(i + 32, len(files))}/{len(files)}", flush=True)
        x = np.concatenate(out); np.save(cache, x)
    clf = LogisticRegression(max_iter=3000, C=10).fit(x, np.array(labels))  # same as food_probe.py
    return classes, clf


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--train", type=pathlib.Path, required=True, help="30VNFoods test split (one folder per dish)")
    ap.add_argument("--per-class", type=int, default=100)
    ap.add_argument("--model", default="MobileCLIP2-S2")
    ap.add_argument("--pretrained", default="dfndr2b")
    ap.add_argument("--check", type=pathlib.Path, help="a folder of photos to compare Core ML with PyTorch")
    a = ap.parse_args()
    if not a.train.is_dir():
        raise SystemExit(f"Not a folder: {a.train}")

    import coremltools as ct
    torch.set_num_threads(4)
    model, _, preprocess = open_clip.create_model_and_transforms(a.model, pretrained=a.pretrained)
    model.eval()
    tok = open_clip.get_tokenizer(a.model)

    print("1/4 labels", flush=True)
    dish_labels = [norm(d) for d in DISHES]  # "pho", as in the spike prompts
    vocab = build_vocab(list(DISHES))
    foods = food_words(vocab) | set(dish_labels)
    vectors = []
    with torch.no_grad():
        for i in range(0, len(vocab), 512):
            vectors.append(model.encode_text(tok([prompt(v, set(dish_labels)) for v in vocab[i:i + 512]])))
    text = torch.nn.functional.normalize(torch.cat(vectors), dim=-1).numpy().astype("<f2")

    print("2/4 food layer", flush=True)
    classes, clf = train_food_layer(model, preprocess, a.train, a.per_class,
                                    a.train.parent / f"build_{a.model}_{a.per_class}.npy")

    print("3/4 Core ML", flush=True)
    enc = ImageEncoder(model).eval()
    traced = torch.jit.trace(enc, torch.rand(1, 3, 256, 256))
    ml = ct.convert(
        traced,
        inputs=[ct.ImageType(name="image", shape=(1, 3, 256, 256), scale=1 / 255.0, color_layout=ct.colorlayout.RGB)],
        outputs=[ct.TensorType(name="embedding")],
        minimum_deployment_target=ct.target.iOS18,
        convert_to="mlprogram",
    )
    ml = ct.optimize.coreml.linear_quantize_weights(ml, ct.optimize.coreml.OptimizationConfig(
        global_config=ct.optimize.coreml.OpLinearQuantizerConfig(mode="linear_symmetric", weight_threshold=2048)))
    ml.short_description = f"{a.model} ({a.pretrained}) image encoder, 8-bit weights, length-1 output (TASK-121.2)"

    print("4/4 write", flush=True)
    OUT.mkdir(parents=True, exist_ok=True)
    pkg = OUT / "MobileCLIPImage.mlpackage"
    if pkg.exists():
        shutil.rmtree(pkg)
    ml.save(str(pkg))
    (OUT / "label_vectors.f16").write_bytes(text.tobytes())
    by_label = {norm(k): v for k, v in DISHES.items()}
    (OUT / "labels.json").write_text(json.dumps({
        "model": a.model, "pretrained": a.pretrained, "dimension": int(text.shape[1]),
        "temperature": 100.0,  # softmax(100 * cosine), as in clip_test.py: the README thresholds use it
        "labels": [by_label.get(v, v) for v in vocab],
        "food": [v in foods for v in vocab],
        "dish": [v in by_label for v in vocab],
    }, ensure_ascii=False, separators=(",", ":")))
    (OUT / "food_layer.json").write_text(json.dumps({
        "classes": [DISHES[c] for c in classes],
        "weights": np.round(clf.coef_, 6).tolist(), "bias": np.round(clf.intercept_, 6).tolist(),
    }, ensure_ascii=False, separators=(",", ":")))

    size = sum(f.stat().st_size for f in OUT.rglob("*") if f.is_file())
    print(f"\n{len(vocab)} labels ({len(foods)} food, {len(DISHES)} dishes), Core ML {a.model}")
    print(f"Vision folder: {size / 1e6:.1f} MB")
    for f in sorted(OUT.rglob("*")):
        if f.is_file():
            print(f"  {f.relative_to(OUT)}: {f.stat().st_size / 1e6:.2f} MB")

    if a.check:
        # The 8-bit weights cannot run on Linux, so compare PyTorch with the same weights rounded the same way.
        q = ImageEncoder(open_clip.create_model_and_transforms(a.model, pretrained=a.pretrained)[0]).eval()
        with torch.no_grad():
            for p in q.parameters():
                if p.numel() >= 2048 and p.dim() > 1:
                    s = p.abs().amax(dim=tuple(range(1, p.dim())), keepdim=True) / 127
                    p.copy_(torch.round(p / s.clamp(min=1e-12)).clamp(-127, 127) * s)
        files = sorted(a.check.rglob("*.jp*g"))[:40]
        sims, same = [], 0
        with torch.no_grad():
            for f in files:
                x = preprocess(Image.open(f).convert("RGB")).unsqueeze(0)
                e1, e2 = enc(x), q(x)
                sims.append(float((e1 * e2).sum()))
                t = torch.from_numpy(text.astype("float32"))
                same += int((e1 @ t.T).argmax() == (e2 @ t.T).argmax())
        print(f"8-bit check on {len(files)} photos: cosine {min(sims):.4f} min, {np.mean(sims):.4f} mean; "
              f"same top-1 label {same}/{len(files)}")


if __name__ == "__main__":
    main()
