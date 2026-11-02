# /// script
# requires-python = ">=3.11"
# dependencies = ["httpx"]
# ///
"""Download a small test set of photos from Wikimedia Commons (free licenses).

Run:  uv run scripts/vision_spike/fetch_photos.py <out_dir>
Safe to run again: files that exist are skipped. Writes <out_dir>/<label>/<n>.jpg and <out_dir>/credits.tsv.
"""
import sys, time, pathlib, httpx

# label -> Commons search text. Label is the answer we expect.
CASES = {
    "pho": "pho bo noodle soup bowl", "banh mi": "banh mi sandwich", "bun bo hue": "bun bo hue",
    "banh xeo": "banh xeo", "goi cuon": "goi cuon spring rolls", "com tam": "com tam broken rice",
    "vietnamese iced coffee": "ca phe sua da", "conical hat": "non la conical hat",
    "ao dai": "ao dai dress", "motorcycle": "motorbike street Hanoi", "desk": "office desk",
    "chair": "wooden chair", "laptop": "laptop computer", "durian": "durian fruit",
    "dragon fruit": "dragon fruit pitaya", "bicycle": "bicycle", "umbrella": "umbrella",
    "teapot": "teapot", "backpack": "backpack", "electric fan": "electric fan",
}
PER_LABEL = 3
API = "https://commons.wikimedia.org/w/api.php"
UA = {"User-Agent": "SaynataVisionSpike/0.1 (https://github.com/tranphuocloc070699/saynata)"}

def main(out: pathlib.Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    credits = []
    with httpx.Client(headers=UA, timeout=30, follow_redirects=True) as c:
        for label, query in CASES.items():
            d = out / label; d.mkdir(exist_ok=True)
            r = c.get(API, params={"action": "query", "format": "json", "generator": "search",
                "gsrsearch": f"{query} filetype:bitmap", "gsrnamespace": 6, "gsrlimit": 12,
                "prop": "imageinfo", "iiprop": "url|extmetadata", "iiurlwidth": 512})
            pages = sorted(r.json().get("query", {}).get("pages", {}).values(), key=lambda p: p.get("index", 99))
            n = 0
            for p in pages:
                if n >= PER_LABEL: break
                info = p["imageinfo"][0]; url = info.get("thumburl", "")
                if not url.lower().endswith((".jpg", ".jpeg", ".png")): continue
                f = d / f"{n}.jpg"
                if not f.exists():
                    img = c.get(url)
                    if img.status_code != 200: continue
                    f.write_bytes(img.content); time.sleep(0.3)
                lic = info.get("extmetadata", {}).get("LicenseShortName", {}).get("value", "?")
                credits.append(f"{label}\t{f.name}\t{p['title']}\t{lic}")
                n += 1
            print(f"{label:24} {n} photos")
    (out / "credits.tsv").write_text("label\tfile\tcommons_title\tlicense\n" + "\n".join(credits) + "\n")

if __name__ == "__main__":
    main(pathlib.Path(sys.argv[1]))
