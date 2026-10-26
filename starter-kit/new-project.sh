#!/usr/bin/env bash
# Creates a new project from this starter kit.
#
#   starter-kit/new-project.sh <target-dir> --name "My App" --stacks backend,web,python,ios \
#       [--java-package com.acme.myapp] [--pitch "One line about the app"]
#
# Copies template/ (Claude config, hooks, skills, scripts, CI, compose) and the picked stacks/,
# fills CLAUDE.md, trims CI and Dependabot to the picked stacks, and makes the first commit.
set -euo pipefail

kit="$(cd "$(dirname "$0")" && pwd)"
target="" name="" stacks="" java_package="" pitch="TODO: one line about the app."
while [ $# -gt 0 ]; do
  case "$1" in
    --name) name="$2"; shift 2 ;;
    --stacks) stacks="$2"; shift 2 ;;
    --java-package) java_package="$2"; shift 2 ;;
    --pitch) pitch="$2"; shift 2 ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) target="$1"; shift ;;
  esac
done
[ -n "$target" ] && [ -n "$name" ] && [ -n "$stacks" ] || { sed -n '2,8p' "$0"; exit 2; }
[ -e "$target" ] && [ -n "$(ls -A "$target" 2>/dev/null)" ] && { echo "$target is not empty" >&2; exit 1; }

IFS=',' read -ra picked <<<"$stacks"
for s in "${picked[@]}"; do
  [ -d "$kit/stacks/$s" ] || { echo "Unknown stack: $s (have: $(ls "$kit/stacks" | tr '\n' ' '))" >&2; exit 2; }
done

mkdir -p "$target"
target="$(cd "$target" && pwd)"
# Template (dotfiles included), then each stack into a folder of the same name.
cp -R "$kit/template/." "$target/"
for s in "${picked[@]}"; do
  mkdir -p "$target/$s"
  tar -C "$kit/stacks/$s" --exclude node_modules --exclude .venv --exclude target --exclude dist \
    --exclude '*.xcodeproj' --exclude .pytest_cache --exclude .ruff_cache --exclude __pycache__ \
    --exclude .env -cf - . | tar -C "$target/$s" -xf -
done

# Remove "# stack:x ... # end-stack" blocks (CI) and "# stack:x" blocks up to the next marker (Dependabot)
# for stacks that were not picked.
trim() {
  local file="$1"
  awk -v keep=",$stacks," '
    /# stack:/ { s=$0; sub(/.*# stack:/, "", s); skip = (index(keep, "," s ",") == 0); next }
    /# end-stack/ { skip = 0; next }
    !skip { print }
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}
trim "$target/.github/workflows/ci.yml"
trim "$target/.github/dependabot.yml"
# Drop the paths-filter lines and outputs of stacks that were not picked.
for s in backend web python ios; do
  if [[ ",$stacks," != *",$s,"* ]]; then
    sed -i.bak "/^      $s: \${{/d; /^            $s: \[/d" "$target/.github/workflows/ci.yml"
  fi
done
rm -f "$target/.github/workflows/ci.yml.bak"

# CLAUDE.md: name, pitch, parts table, stack rules.
table="" rules=""
for s in "${picked[@]}"; do
  title=$(sed -n '1s/^### //p' "$kit/stacks/$s/STACK.md")
  stack_desc="${title#*, }"; table+="| ${title%% (*} | ${stack_desc%)} | \`$s/\` |"$'\n'
  rules+="$(cat "$kit/stacks/$s/STACK.md")"$'\n\n'
  rm -f "$target/$s/STACK.md"
done
python3 - "$target/CLAUDE.md" "$name" "$pitch" "$table" "$rules" <<'EOF'
import sys
path, name, pitch, table, rules = sys.argv[1:]
s = open(path).read()
s = s.replace("__APP_NAME__", name).replace("__ONE_LINE_PITCH__", pitch)
s = s.replace("<!-- new-project.sh fills this table from the stacks you picked -->\n__PARTS_TABLE__", table.rstrip())
s = s.replace("<!-- new-project.sh appends the rules of each picked stack here -->\n__STACK_RULES__", rules.rstrip() + "\n")
open(path, "w").write(s)
EOF
{ grep -rl "__APP_NAME__" "$target" --exclude-dir=node_modules 2>/dev/null || true; } | xargs -r sed -i.bak "s/__APP_NAME__/$name/g"
find "$target" -name '*.bak' -delete

# Java package rename (com.example.app → your package).
if [[ ",$stacks," == *",backend,"* ]] && [ -n "$java_package" ]; then
  for root in src/main/java src/test/java; do
    from="$target/backend/$root/com/example/app"
    to="$target/backend/$root/${java_package//.//}"
    mkdir -p "$(dirname "$to")" && mv "$from" "$to"
    rmdir -p "$target/backend/$root/com/example" 2>/dev/null || true
  done
  grep -rl "com.example.app" "$target/backend/src" | xargs sed -i.bak "s/com\.example\.app/$java_package/g"
  sed -i.bak "s#<groupId>com.example</groupId>#<groupId>${java_package%.*}</groupId>#; s#<artifactId>app</artifactId>#<artifactId>${java_package##*.}</artifactId>#" "$target/backend/pom.xml"
  find "$target/backend" -name '*.bak' -delete
fi

chmod +x "$target"/scripts/*.sh "$target"/.claude/hooks/*.sh
[ -f "$target/backend/mvnw" ] && chmod +x "$target/backend/mvnw"

cd "$target"
git init -q -b main
git add -A
git -c commit.gpgsign=false commit -q -m "chore: start $name from starter kit ($stacks)"

cat <<EOF
Created $target with: $stacks

Next:
  cd $target
  scripts/doctor.sh                  # check tools and .env files
  cp .env.example .env               # and each part's .env.example
  lefthook install                   # git hooks (secret scan, format, commit message)
  make up && make check              # start Postgres, run every part's checks
  gh repo create --private --source . --push
  # GitHub → Settings → General → "Automatically delete head branches": on
  gh label create human-reviewed --color 0E8A16 --description "A human read every line"
  # GitHub → Settings → Rules → protect main: PR required, CI must pass, no force-push
EOF
