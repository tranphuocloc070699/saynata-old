#!/usr/bin/env bash
# Checks that the tools this project needs are installed, and that .env has every key in .env.example.
#   scripts/doctor.sh
set -uo pipefail

ok=true
need() {
  if command -v "$1" >/dev/null 2>&1; then printf '  ok   %s\n' "$1"; else printf '  MISS %s  (%s)\n' "$1" "$2"; ok=false; fi
}

echo "Tools:"
need git "https://git-scm.com"
need jq "brew install jq"
need gh "brew install gh"
need lefthook "brew install lefthook   # git hooks"
need gitleaks "brew install gitleaks   # secret scan"
need docker "https://docs.docker.com/get-docker/  (or OrbStack on macOS)"
[ -d backend ] && need java "brew install --cask temurin@21"
[ -d web ] && need node "brew install node@22   (or fnm/mise)"
[ -d python ] && need uv "brew install uv"
[ -d ios ] && need xcodegen "brew install xcodegen"

echo ".env keys:"
for example in $(find . -name .env.example -not -path '*/node_modules/*'); do
  env_file="${example%.example}"
  if [ ! -f "$env_file" ]; then
    echo "  MISS $env_file  (cp $example $env_file and fill it in)"; ok=false; continue
  fi
  # Compare key names only; values are never printed.
  missing=$(comm -23 <(grep -Eo '^[A-Z0-9_]+=' "$example" | sort -u) <(grep -Eo '^[A-Z0-9_]+=' "$env_file" | sort -u))
  if [ -n "$missing" ]; then echo "  MISS in $env_file: $(echo "$missing" | tr -d = | tr '\n' ' ')"; ok=false
  else echo "  ok   $env_file"; fi
done

$ok && echo "All good." || { echo "Fix the MISS lines above."; exit 1; }
