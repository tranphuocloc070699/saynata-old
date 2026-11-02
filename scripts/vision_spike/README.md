# Vision spike (TASK-120): name the thing in a photo

Goal: point the camera at a thing (a desk, a bowl of phở, a bánh mì) and show its simple English explanation.
This folder measures accuracy and speed **before** any UI or backend code. Results from 2026-11-02, cloud session, CPU only.

| Script | What it does | Cost |
|---|---|---|
| `clip_test.py` | Zero-shot MobileCLIP2-S2: the labels are the concrete nouns of `existing_words.txt` (WordNet physical senses, no plurals) + 30 dishes | free, ~5 min |
| `food_probe.py` | Trains one small layer (linear probe) on frozen MobileCLIP image vectors for 30 Vietnamese dishes | free, ~20 min |
| `llm_test.py` | The same photos through Gemini flash-lite | **paid**, under 1 US cent for ~90 photos; needs `GEMINI_API_KEY` |
| `fetch_photos.py` | Test photos from Wikimedia Commons | free; **blocked from cloud IPs** (403), works from a Mac |

## Test data (not in git)

- **Vietnamese food:** [30VNFoods](https://huggingface.co/datasets/vuongnhathien/30VNFoods) (CC BY-NC-SA 4.0, non-commercial):
  the `test` split (5,040 photos, 100 per dish used) trains the layer, the `validation` split (2,515 photos) scores it.
  To ship a trained layer in the App Store app, train it on data we may use commercially (our own photos, or a dataset with a commercial license).
- **Everyday objects:** 27 classes × 10 photos from the ImageNet validation set (research use only), for example desk, chair, laptop, wok, motor scooter.

```bash
uv run scripts/vision_spike/clip_test.py --objects <objects dir> --foods <30VNFoods/validation> --per-class 10
```

```bash
uv run scripts/vision_spike/food_probe.py --train <30VNFoods/test> --eval <30VNFoods/validation>
```

In a Claude cloud session, put `NLTK_ALLOW_PROXIED_URLOPEN=1` before the first command.

## Results

### 1. Zero-shot MobileCLIP2-S2, 5,157 labels from the dictionary

| Group | Photos | Top-1 | Top-5 |
|---|---|---|---|
| Objects | 270 | 57% | 77% |
| Vietnamese food | 300 | 38% | 66% |

| Confidence ≥ | Coverage | Top-1 on those |
|---|---|---|
| 0.3 | 76% | 55% |
| 0.5 | 49% | 66% |
| 0.6 | 40% | 68% |
| 0.7 | 29% | 71% |

Strong: pineapple, teapot, motor scooter, toaster, electric fan, bánh xèo, gỏi cuốn, bún thịt nướng.
Weak: sunglasses, wok, desk ("workstation"), and look-alike dishes (hủ tiếu, bánh canh and phở; bánh tét and bánh chưng).
Some misses are near-synonyms in the label list (bag for backpack, cushion for pillow), so a cleaner label list helps.
CPU: 227 ms per photo (4 threads); the iPhone Neural Engine is much faster.

### 2. Trained food layer (linear probe), 30 dishes

| Method | Top-1 | Top-5 |
|---|---|---|
| Zero-shot, only the 30 dish names | 49% | 76% |
| **Trained layer** | **87%** | **98%** |

| Confidence ≥ | Coverage | Top-1 on those |
|---|---|---|
| 0.5 | 80% | 95% |
| 0.7 | 64% | 98% |
| 0.8 | 55% | 99% |
| 0.9 | 38% | 99% |

Hardest: hủ tiếu 59% (confused with bánh canh), bánh đúc 73%, bún bò Huế 76% (with phở), bánh canh 77%.
Best: cơm tấm and cá kho tộ 100%, bánh mì and bánh pía 98%. The layer is 15,390 numbers (about 60 KB).

Caveat: train and test photos come from the same dataset, so real camera photos will score lower.
The layer was only shown food photos; how often it calls a non-food photo a dish is not measured yet.

### 3. Vision LLM (Gemini)

Not run yet: the cloud session had no `GEMINI_API_KEY`. Next session: `llm_test.py --per-class 3`.

## Recommended cascade (to confirm after step 3)

1. MobileCLIP image vector on the phone, once per photo.
2. If the top zero-shot label is a food word or a dish, run the food layer; **≥ 0.7** shows the dish card (about 64% of food photos, 98% right).
3. Else, if zero-shot is **≥ 0.7**, show that word's card from the dictionary (no LLM call).
4. Else show the top 3 labels as chips (top-5 is right 77% of the time for objects) and an "ask AI" button,
   which sends the photo to the backend vision LLM (through `limits/ClaudeGate`); cache its answer like words and sentences.
