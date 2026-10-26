#!/usr/bin/env bash
# Moves a backend/.env from the old Claude keys to the new LLM keys (TASK-117). Safe to run again and again.
#
#   scripts/migrate-env.sh              step 1, BEFORE the deploy: adds DEEPSEEK_API_KEY and GEMINI_API_KEY (asks for
#                                       the ones that are missing) and copies the daily budget to LLM_DAILY_BUDGET_USD.
#                                       The old keys stay, so the running backend keeps working.
#   scripts/migrate-env.sh --cleanup    step 2, AFTER the deploy works: removes the old keys.
#   scripts/migrate-env.sh [--cleanup] /path/to/.env     another file (default: backend/.env)
#
# It saves a copy first (.env.bak-<time>, mode 600) and only when something changes. It never prints a value, only
# key names. Order for production: doc-11, "Switching LLM keys".
set -euo pipefail

cleanup=false
if [ "${1:-}" = "--cleanup" ]; then
  cleanup=true
  shift
fi
env_file="${1:-$(dirname "$0")/../.env}"

if [ ! -f "$env_file" ]; then
  echo "No env file at $env_file." >&2
  exit 1
fi

# Keys the new backend no longer reads.
old_keys="CLAUDE_API_KEY CLAUDE_BASE_URL CLAUDE_AUTH_TOKEN CLAUDE_MODEL CLAUDE_SCENE_MODEL CLAUDE_EFFORT AI_SCENE_DAILY_USD CLAUDE_TEMPERATURE CLAUDE_WARM_UP"

backup_done=false
backup() {
  if [ "$backup_done" = false ]; then
    local copy
    copy="$env_file.bak-$(date +%Y%m%d%H%M%S)-$$"
    cp -p "$env_file" "$copy"
    chmod 600 "$copy"
    echo "Saved a copy: $copy"
    backup_done=true
  fi
}

# True when KEY= exists, with any value (the value is never printed).
has_key() { grep -Eq "^$1=" "$env_file"; }
# True when KEY= exists with a non-empty value.
has_value() { grep -Eq "^$1=.+" "$env_file"; }
get_value() { grep -E "^$1=" "$env_file" | tail -n 1 | cut -d= -f2-; }

remove_key() {
  backup
  local tmp
  tmp="$(mktemp)"
  grep -Ev "^$1=" "$env_file" > "$tmp" || true
  cat "$tmp" > "$env_file"
  rm -f "$tmp"
}

set_key() {   # set_key NAME VALUE: replaces the line, or adds it at the end
  backup
  if has_key "$1"; then
    remove_key "$1"
  fi
  [ -n "$(tail -c1 "$env_file")" ] && printf '\n' >> "$env_file"
  printf '%s=%s\n' "$1" "$2" >> "$env_file"
}

ask_key() {   # ask_key NAME REQUIRED(true|false)
  local name="$1" required="$2" value=""
  if has_value "$name"; then
    echo "$name: already set."
    return
  fi
  if [ ! -t 0 ]; then
    [ "$required" = true ] && { echo "$name is missing and there is no terminal to ask for it." >&2; exit 1; }
    echo "$name: not set (skipped, no terminal)."
    return
  fi
  read -r -s -p "$name$([ "$required" = false ] && echo ' (Enter to skip)'): " value
  echo
  if [ -z "$value" ]; then
    [ "$required" = true ] && { echo "$name is required." >&2; exit 1; }
    echo "$name: skipped."
    return
  fi
  set_key "$name" "$value"
  echo "$name: saved."
}

if [ "$cleanup" = false ]; then
  ask_key DEEPSEEK_API_KEY true
  ask_key GEMINI_API_KEY false
  if has_value CLAUDE_DAILY_BUDGET_USD && ! has_key LLM_DAILY_BUDGET_USD; then
    set_key LLM_DAILY_BUDGET_USD "$(get_value CLAUDE_DAILY_BUDGET_USD)"
    echo "LLM_DAILY_BUDGET_USD: copied from CLAUDE_DAILY_BUDGET_USD."
  fi
  echo "Done. Next: merge to main, wait for the deploy, then run this script with --cleanup."
  exit 0
fi

# --cleanup: the new backend must be running with the new keys first, so check they are there.
if ! has_value DEEPSEEK_API_KEY; then
  echo "DEEPSEEK_API_KEY is not set. Run this script without --cleanup first." >&2
  exit 1
fi
if has_key CLAUDE_DAILY_BUDGET_USD; then
  if has_key LLM_DAILY_BUDGET_USD; then
    echo "CLAUDE_DAILY_BUDGET_USD: removed (LLM_DAILY_BUDGET_USD already exists)."
  else
    set_key LLM_DAILY_BUDGET_USD "$(get_value CLAUDE_DAILY_BUDGET_USD)"
    echo "CLAUDE_DAILY_BUDGET_USD: renamed to LLM_DAILY_BUDGET_USD."
  fi
  remove_key CLAUDE_DAILY_BUDGET_USD
fi
for key in $old_keys; do
  if has_key "$key"; then
    remove_key "$key"
    echo "$key: removed."
  fi
done
echo "Cleanup done."
