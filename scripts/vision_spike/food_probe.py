# /// script
# requires-python = ">=3.11"
# dependencies = ["torch", "torchvision", "open_clip_torch>=3.1", "timm", "pillow", "scikit-learn"]
# [tool.uv]
# exclude-newer = "2026-10-31T00:00:00Z"  # same package versions on every run
# [[tool.uv.index]]
# name = "pytorch-cpu"
# url = "https://download.pytorch.org/whl/cpu"
# explicit = true  # only torch/torchvision come from here; everything else from PyPI
# [tool.uv.sources]
# torch = { index = "pytorch-cpu" }
# torchvision = { index = "pytorch-cpu" }
# ///
"""Linear probe: train one small layer on frozen MobileCLIP image vectors to name 30 Vietnamese dishes.

Run (from the repo root):
  uv run scripts/vision_spike/food_probe.py --train <30VNFoods/test> --eval <30VNFoods/validation> [--per-class 100]
Free, CPU only (about 20 minutes). Image vectors are cached next to the photos, so a second run takes seconds.
Compares: zero-shot with only the 30 dish names vs. the trained layer, on photos the layer never saw.
"""
import argparse, pathlib, random, time
import numpy as np, torch, open_clip
from PIL import Image
from sklearn.linear_model import LogisticRegression


def embed(model, preprocess, files, cache: pathlib.Path) -> np.ndarray:
    if cache.exists():
        return np.load(cache)
    out = []
    with torch.no_grad():
        for i in range(0, len(files), 32):
            batch = torch.stack([preprocess(Image.open(f).convert("RGB")) for f in files[i:i + 32]])
            out.append(torch.nn.functional.normalize(model.encode_image(batch), dim=-1).numpy())
            print(f"  {cache.stem}: {min(i + 32, len(files))}/{len(files)}", flush=True)
    arr = np.concatenate(out)
    np.save(cache, arr)
    return arr


def load(root: pathlib.Path, per_class: int, classes: list[str]):
    random.seed(0)
    files, labels = [], []
    for ci, c in enumerate(classes):
        fs = sorted((root / c).glob("*.jp*g")) + sorted((root / c).glob("*.png"))
        for f in (random.sample(fs, min(per_class, len(fs))) if per_class else fs):
            files.append(f); labels.append(ci)
    return files, np.array(labels)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--train", type=pathlib.Path, required=True)
    ap.add_argument("--eval", type=pathlib.Path, required=True)
    ap.add_argument("--per-class", type=int, default=100, help="training photos per dish (0 = all)")
    ap.add_argument("--model", default="MobileCLIP2-S2")
    ap.add_argument("--pretrained", default="dfndr2b")
    a = ap.parse_args()
    classes = sorted(p.name for p in a.train.iterdir() if p.is_dir())
    if classes != sorted(p.name for p in a.eval.iterdir() if p.is_dir()):
        raise SystemExit("train and eval folders must have the same dish folders")

    torch.set_num_threads(4)
    model, _, preprocess = open_clip.create_model_and_transforms(a.model, pretrained=a.pretrained)
    model.eval()
    tok = open_clip.get_tokenizer(a.model)

    tr_f, tr_y = load(a.train, a.per_class, classes)
    ev_f, ev_y = load(a.eval, 0, classes)
    t0 = time.time()
    tr_x = embed(model, preprocess, tr_f, a.train.parent / f"img_train_{a.model}_{len(tr_f)}.npy")
    ev_x = embed(model, preprocess, ev_f, a.eval.parent / f"img_eval_{a.model}_{len(ev_f)}.npy")
    print(f"embedded in {time.time() - t0:.0f}s")

    with torch.no_grad():
        text = model.encode_text(tok([f"a photo of {c.lower()}, a Vietnamese dish" for c in classes]))
        text = torch.nn.functional.normalize(text, dim=-1).numpy()
    zs = (ev_x @ text.T).argmax(1)

    clf = LogisticRegression(max_iter=3000, C=10).fit(tr_x, tr_y)
    prob = clf.predict_proba(ev_x)
    pr = prob.argmax(1)
    top5 = np.argsort(-prob, 1)[:, :5]

    print(f"\n## Vietnamese food, {len(classes)} dishes, {len(tr_f)} training / {len(ev_f)} test photos ({a.model})\n")
    print("| Method | Top-1 | Top-5 |\n|---|---|---|")
    zs5 = np.argsort(-(ev_x @ text.T), 1)[:, :5]
    print(f"| Zero-shot, only the 30 dish names | {(zs == ev_y).mean():.0%} | {(zs5 == ev_y[:, None]).any(1).mean():.0%} |")
    print(f"| Trained layer (linear probe) | {(pr == ev_y).mean():.0%} | {(top5 == ev_y[:, None]).any(1).mean():.0%} |")
    print("\n| Confidence ≥ | Coverage | Top-1 on those |\n|---|---|---|")
    conf = prob.max(1)
    for th in (0.5, 0.7, 0.8, 0.9):
        m = conf >= th
        print(f"| {th:.1f} | {m.mean():.0%} | {(pr[m] == ev_y[m]).mean():.0%} |")
    print("\n| Dish | Top-1 | Most confused with |\n|---|---|---|")
    for ci, c in enumerate(classes):
        m = ev_y == ci
        wrong = pr[m][pr[m] != ci]
        conf_with = classes[np.bincount(wrong, minlength=len(classes)).argmax()] if len(wrong) else ""
        print(f"| {c} | {(pr[m] == ci).mean():.0%} | {conf_with} |")
    print(f"\nLayer size: {clf.coef_.size + clf.intercept_.size} numbers (~{(clf.coef_.size + clf.intercept_.size) * 4 // 1024} KB as float32)")


if __name__ == "__main__":
    main()
