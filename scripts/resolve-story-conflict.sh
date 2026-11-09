#!/usr/bin/env bash
# Resolves a git merge conflict in the append-only story docs (doc-7 decisions, doc-9 timeline):
# keeps the rows of both sides, and in the frontmatter keeps one value per key (the last one, the newest).
# Run from anywhere inside the repo while a merge has stopped on doc-7 or doc-9:  scripts/resolve-story-conflict.sh
# Safe to run again. It touches only conflicted doc-7 / doc-9 files and stops if any other file is conflicted
# (resolve those by hand), so nothing else is changed. Then: git commit --no-edit
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

echo "1/3 Finding conflicted files"
# A read loop, not mapfile: macOS ships bash 3.2, which has no mapfile.
conflicted=()
while IFS= read -r f; do conflicted+=("$f"); done < <(git diff --name-only --diff-filter=U)
[ "${#conflicted[@]}" -gt 0 ] || { echo "No conflicted files. Nothing to do."; exit 0; }
story=()
for f in "${conflicted[@]}"; do
  case "$f" in
    backlog/docs/story/doc-7*|backlog/docs/story/doc-9*) story+=("$f") ;;
    *) echo "Stopped, nothing changed: $f is conflicted too. This script only handles doc-7 and doc-9." >&2; exit 1 ;;
  esac
done

echo "2/3 Keeping both sides' rows and one frontmatter value per key"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
for f in "${story[@]}"; do
  git show ":1:$f" > "$tmp/base" 2>/dev/null || : > "$tmp/base"
  git show ":2:$f" > "$tmp/ours"
  git show ":3:$f" > "$tmp/theirs"
  python3 - "$f" "$tmp" <<'PY'
import subprocess, sys
path, tmp = sys.argv[1], sys.argv[2]

def split(name):
    lines = open(f"{tmp}/{name}", encoding="utf-8").read().split("\n")
    if lines and lines[0] == "---" and "---" in lines[1:]:
        end = lines.index("---", 1)
        return lines[1:end], lines[end + 1:]
    return [], lines

parts = {n: split(n) for n in ("base", "ours", "theirs")}
# Body: git's union merge (the rows of both sides, no markers).
for n, (_, body) in parts.items():
    open(f"{tmp}/{n}.body", "w", encoding="utf-8").write("\n".join(body))
body = subprocess.run(["git", "merge-file", "--union", "-p", f"{tmp}/ours.body", f"{tmp}/base.body",
                       f"{tmp}/theirs.body"], capture_output=True, text=True).stdout
# Frontmatter: one line per key, ours first; a *_date key keeps the newest value.
order, values = [], {}
for l in parts["ours"][0] + parts["theirs"][0]:
    key = l.split(":", 1)[0]
    if key not in values:
        order.append(key); values[key] = l
    elif key.endswith("_date"):
        values[key] = max(values[key], l)
front = ["---"] + [values[k] for k in order] + ["---"] if order else []
open(path, "w", encoding="utf-8").write("\n".join(front + [body]) if front else body)
print("    " + path)
PY
  git add "$f"
done

echo "3/3 Checking"
if grep -n -E '^(<<<<<<< |>>>>>>> )' "${story[@]}"; then
  echo "Conflict markers are still there; check the files above." >&2; exit 1
fi
echo "Done. Look at the end of the table, then run: git commit --no-edit"
