# /// script
# requires-python = ">=3.11"
# dependencies = ["httpx"]
# [tool.uv]
# exclude-newer = "2026-10-31T00:00:00Z"
# ///
"""Ask a vision LLM (Gemini) to name the thing in each photo, on the same photos as clip_test.py.

PAID: about 1 small request per photo (gemini flash-lite: well under 1 US cent for 100 photos).
Needs GEMINI_API_KEY in the environment (cloud: environment secrets; local: backend/.env).
Run (from the repo root):
  uv run scripts/vision_spike/llm_test.py --objects <dir> --foods <dir> [--per-class 3] [--model gemini-3.5-flash-lite]
Safe to run again: answers are cached in <foods>/../llm_answers.json, so only new photos cost money.
"""
import argparse, base64, json, os, pathlib, random, time, unicodedata
import httpx

PROMPT = ("Name the main thing in this photo with one short common English noun phrase, lowercase. "
          "If it is a Vietnamese dish, give its Vietnamese name without accents (for example: pho, banh mi). "
          "Answer with the name only.")


def norm(s: str) -> str:
    return unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower().strip(" .\n")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--objects", type=pathlib.Path, required=True)
    ap.add_argument("--foods", type=pathlib.Path, required=True)
    ap.add_argument("--per-class", type=int, default=3)
    ap.add_argument("--model", default=os.environ.get("GEMINI_MODEL", "gemini-3.5-flash-lite"))
    a = ap.parse_args()
    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        raise SystemExit("GEMINI_API_KEY is not set; nothing was sent.")

    cache_file = a.foods.parent / "llm_answers.json"
    cache = json.loads(cache_file.read_text()) if cache_file.exists() else {}
    random.seed(0)
    cases = []
    for group, root in (("object", a.objects), ("food", a.foods)):
        for cls in sorted(p for p in root.iterdir() if p.is_dir()):
            files = sorted(cls.glob("*.jp*g"))
            cases += [(f, norm(cls.name), group) for f in random.sample(files, min(a.per_class, len(files)))]

    url = f"https://generativelanguage.googleapis.com/v1beta/models/{a.model}:generateContent"
    rows, times = [], []
    with httpx.Client(timeout=60) as c:
        for f, want, group in cases:
            k = f"{a.model}:{f}"
            if k not in cache:
                body = {"contents": [{"parts": [{"text": PROMPT}, {"inline_data": {"mime_type": "image/jpeg",
                        "data": base64.b64encode(f.read_bytes()).decode()}}]}]}
                t0 = time.time()
                for wait in (0, 5, 15, 30, 60):  # the free tier answers 429 when it is busy; wait and try again
                    time.sleep(wait)
                    # the key goes in a header, so it never shows in an error message or log
                    r = c.post(url, headers={"x-goog-api-key": key}, json=body)
                    if r.status_code != 429:
                        break
                if r.is_error:
                    raise SystemExit(f"Gemini answered {r.status_code}: {r.text[:300]}")
                times.append(time.time() - t0)
                cache[k] = r.json()["candidates"][0]["content"]["parts"][0]["text"]
                cache_file.write_text(json.dumps(cache, indent=1))
            rows.append((group, want, norm(cache[k])))

    print(f"\n## {a.model}, {len(rows)} photos\n")
    if times:
        print(f"Latency: {sum(times) / len(times):.1f} s/photo (from this cloud session)\n")
    print("| Group | Photos | Exact or contains the label |\n|---|---|---|")
    for g in ("object", "food"):
        r = [x for x in rows if x[0] == g]
        ok = sum(x[1] == x[2] or x[1].split()[-1] in x[2].split() for x in r)
        print(f"| {g} | {len(r)} | {ok / len(r):.0%} |")
    print("\n| Expected | Answers |\n|---|---|")
    for want in sorted({x[1] for x in rows}):
        print(f"| {want} | {', '.join(x[2] for x in rows if x[1] == want)} |")


if __name__ == "__main__":
    main()
