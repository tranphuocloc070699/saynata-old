# /// script
# requires-python = ">=3.11"
# dependencies = ["torch", "torchvision", "open_clip_torch>=3.1", "timm", "pillow", "nltk"]
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
"""Zero-shot test: can MobileCLIP name everyday objects and Vietnamese dishes from Saynata's own word list?

Run (from the repo root):
  uv run scripts/vision_spike/clip_test.py --objects <dir> --foods <dir> [--model MobileCLIP2-S2] [--per-class 10]
<dir> holds one folder per expected label with photos inside (objects/desk/0.jpg, foods/Pho/12.jpg).
In a Claude cloud session, add NLTK_ALLOW_PROXIED_URLOPEN=1 before uv (NLTK refuses downloads through a proxy otherwise).
Free, CPU only, safe to run again (text embeddings are cached in the scratch folder next to the photos).
Prints a Markdown report: top-1 / top-5 accuracy, and accuracy vs. coverage per confidence threshold.
"""
import argparse, pathlib, random, time, unicodedata
import torch, open_clip, nltk
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
PHYSICAL = {"noun.artifact", "noun.food", "noun.plant", "noun.animal", "noun.object", "noun.body"}
# Accepted answers per expected label (besides the label itself and a matching last word).
SYN = {
    "chair": {"armchair"}, "laptop": {"notebook", "notebook computer"}, "mobile phone": {"cellphone", "smartphone", "phone", "cell phone"},
    "motor scooter": {"scooter", "moped", "motorbike", "motorcycle"}, "bicycle": {"bike", "mountain bike"},
    "television": {"tv", "television set"}, "mug": {"cup", "coffee mug"}, "computer mouse": {"mouse"},
    "keyboard": {"computer keyboard"}, "shoe": {"sneaker", "trainer", "running shoe"}, "bookcase": {"bookshelf", "shelf", "bookshelves"},
    "water bottle": {"bottle"}, "electric fan": {"fan"}, "refrigerator": {"fridge"}, "sunglasses": {"shades"},
}


def norm(s: str) -> str:
    return unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower().strip()


def build_vocab(dishes: list[str]) -> list[str]:
    nltk.download("wordnet", quiet=True)
    from nltk.corpus import wordnet as wn
    words = []
    for w in (ROOT / "existing_words.txt").read_text().splitlines():
        w = w.strip().lower()
        if not w or not w[0].isalpha():
            continue
        all_senses = wn.synsets(w.replace(" ", "_"))
        # keep the word only when its most common sense is a physical noun (desk, pho, durian), not "run" or "idea"
        # skip plurals ("chairs"); the singular is already in the list
        if all_senses and all_senses[0].pos() == "n" and all_senses[0].lexname() in PHYSICAL \
                and wn.morphy(w.replace(" ", "_"), wn.NOUN) in (w.replace(" ", "_"), None):
            words.append(w)
    return sorted(set(words) | {norm(d) for d in dishes})


def prompt(label: str, dishes: set[str]) -> str:
    return f"a photo of {label}, a Vietnamese dish" if label in dishes else f"a photo of a {label}"


def senses(word: str) -> set:
    from nltk.corpus import wordnet as wn
    return set(wn.synsets(word.replace(" ", "_"), pos=wn.NOUN))


def correct(pred: str, want: str) -> bool:
    # same word, a listed synonym, same head noun, or a shared WordNet meaning (knapsack = backpack, telly = television)
    return (pred == want or pred in SYN.get(want, ()) or pred.split()[-1] == want.split()[-1]
            or bool(senses(pred) & senses(want)))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--objects", type=pathlib.Path, required=True)
    ap.add_argument("--foods", type=pathlib.Path, required=True)
    ap.add_argument("--model", default="MobileCLIP2-S2")
    ap.add_argument("--pretrained", default="dfndr2b")
    ap.add_argument("--per-class", type=int, default=10)
    a = ap.parse_args()
    for d in (a.objects, a.foods):
        if not d.is_dir():
            raise SystemExit(f"Not a folder: {d}")

    dishes = sorted(p.name for p in a.foods.iterdir() if p.is_dir())
    dish_set = {norm(d) for d in dishes}
    vocab = build_vocab(dishes)
    obj_labels = sorted(p.name for p in a.objects.iterdir() if p.is_dir())
    missing = [l for l in obj_labels if l not in vocab]
    vocab = sorted(set(vocab) | set(obj_labels))

    torch.set_num_threads(4)
    model, _, preprocess = open_clip.create_model_and_transforms(a.model, pretrained=a.pretrained)
    model.eval()
    tok = open_clip.get_tokenizer(a.model)

    cache = a.foods.parent / f"text_{a.model}_{len(vocab)}.pt"
    if cache.exists():
        text = torch.load(cache)
    else:
        t0, chunks = time.time(), []
        with torch.no_grad():
            for i in range(0, len(vocab), 512):
                chunks.append(model.encode_text(tok([prompt(v, dish_set) for v in vocab[i:i + 512]])))
        text = torch.nn.functional.normalize(torch.cat(chunks), dim=-1)
        torch.save(text, cache)
        print(f"encoded {len(vocab)} labels in {time.time() - t0:.0f}s")

    random.seed(0)
    cases = []  # (path, expected label, group)
    for group, root in (("object", a.objects), ("food", a.foods)):
        for cls in sorted(p for p in root.iterdir() if p.is_dir()):
            files = sorted(cls.glob("*.jp*g")) + sorted(cls.glob("*.png"))
            for f in random.sample(files, min(a.per_class, len(files))):
                cases.append((f, norm(cls.name), group))

    rows, times = [], []
    with torch.no_grad():
        for f, want, group in cases:
            img = preprocess(Image.open(f).convert("RGB")).unsqueeze(0)
            t0 = time.time()
            e = torch.nn.functional.normalize(model.encode_image(img), dim=-1)
            times.append(time.time() - t0)
            probs = (100 * e @ text.T).softmax(-1)[0]
            top = probs.topk(5)
            preds = [vocab[i] for i in top.indices.tolist()]
            rows.append((group, want, preds, top.values[0].item(), f.name))

    print(f"\n## {a.model} ({a.pretrained}), {len(vocab)} labels, {len(rows)} photos\n")
    print(f"CPU image encode: {1000 * sum(times) / len(times):.0f} ms/photo (4 threads; the phone's Neural Engine is much faster)")
    if missing:
        print(f"Test labels not in the dictionary list (added): {', '.join(missing)}")
    print("\n| Group | Photos | Top-1 | Top-5 |\n|---|---|---|---|")
    for g in ("object", "food"):
        r = [x for x in rows if x[0] == g]
        t1 = sum(correct(x[2][0], x[1]) for x in r) / len(r)
        t5 = sum(any(correct(p, x[1]) for p in x[2]) for x in r) / len(r)
        print(f"| {g} | {len(r)} | {t1:.0%} | {t5:.0%} |")
    print("\n| Confidence ≥ | Coverage (answered on phone) | Top-1 on those |\n|---|---|---|")
    for th in (0.2, 0.3, 0.4, 0.5, 0.6, 0.7):
        r = [x for x in rows if x[3] >= th]
        acc = sum(correct(x[2][0], x[1]) for x in r) / len(r) if r else 0
        print(f"| {th:.1f} | {len(r) / len(rows):.0%} | {acc:.0%} |")
    print("\n| Expected | Top-1 accuracy | Common wrong answers |\n|---|---|---|")
    for want in sorted({x[1] for x in rows}):
        r = [x for x in rows if x[1] == want]
        wrong = [x[2][0] for x in r if not correct(x[2][0], want)]
        common = ", ".join(f"{w} ×{wrong.count(w)}" for w in sorted(set(wrong), key=wrong.count, reverse=True)[:3])
        print(f"| {want} | {sum(correct(x[2][0], want) for x in r)}/{len(r)} | {common} |")


if __name__ == "__main__":
    main()
