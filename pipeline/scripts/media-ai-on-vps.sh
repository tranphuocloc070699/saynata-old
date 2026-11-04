#!/usr/bin/env bash
# TASK-115: draw the AI pictures on the VPS, so the Mac can sleep. Claude calls go through the gateway
# (STEYG with Claude models: the keys in pipeline/.env.steyg, see gateway_lines); Codex draws with the server's ChatGPT login.
#
# Run it on the Mac, from anywhere in the repo:
#   pipeline/scripts/media-ai-on-vps.sh steyg    # create pipeline/.env.steyg: asks only for the STEYG token
#   pipeline/scripts/media-ai-on-vps.sh gateway  # show the gateway keys and models it will use (token hidden)
#   pipeline/scripts/media-ai-on-vps.sh setup    # copy the pipeline + gateway keys to the VPS, install, check (cents)
#   pipeline/scripts/media-ai-on-vps.sh start    # start the run in the background on the VPS, then close the Mac
#   pipeline/scripts/media-ai-on-vps.sh status   # running or not, the last log lines
#   pipeline/scripts/media-ai-on-vps.sh stop     # stop it; 'start' continues later
#   pipeline/scripts/media-ai-on-vps.sh link     # after the run: copy, link, then export the app bundle here
#
# Safe to run again: every step checks first and continues where it stopped. Old Pixabay rows and files are kept.
# Settings (env): VPS (ssh host, default vps_sieutoc), MAX_COST (USD cap per pass, default 40), WORKERS (default 4).
set -euo pipefail

VPS="${VPS:-vps_sieutoc}"
REMOTE_DIR='~/saynata-pipeline/pipeline'

cd "$(dirname "$0")/.."   # pipeline/
step() { printf '\n==> %s\n' "$*"; }
die()  { printf 'Stopped: %s\n' "$*" >&2; exit 1; }
remote() { ssh "$VPS" "MAX_COST='${MAX_COST:-40}' WORKERS='${WORKERS:-4}' $REMOTE_DIR/scripts/vps-media-ai-remote.sh $1"; }

check_ssh() { ssh -o BatchMode=yes -o ConnectTimeout=10 "$VPS" true || die "cannot reach $VPS over ssh"; }

# The gateway keys for the run, as CLAUDE_* lines (what pipeline/src/pipeline/llm.py reads).
# TEMPORARY (TASK-115): pipeline/.env.steyg (git-ignored) holds the STEYG keys in Claude Code's ANTHROPIC_* form:
#   export ANTHROPIC_BASE_URL="https://steyg.one/api"   export ANTHROPIC_AUTH_TOKEN="sk-steyg-..."
#   export ANTHROPIC_DEFAULT_SONNET_MODEL=...  (scene)   export ANTHROPIC_DEFAULT_HAIKU_MODEL=...  (picture checks)
# STEYG_SCENE_MODEL / STEYG_GUESS_MODEL in that file win. Without the file, the CLAUDE_* lines of pipeline/.env are used.
gateway_lines() {
  if [ -f .env.steyg ]; then
    (
      set +u; set -a
      # shellcheck disable=SC1091
      . ./.env.steyg
      scene="${STEYG_SCENE_MODEL:-${ANTHROPIC_DEFAULT_SONNET_MODEL:-$ANTHROPIC_MODEL}}"
      guess="${STEYG_GUESS_MODEL:-${ANTHROPIC_DEFAULT_HAIKU_MODEL:-$ANTHROPIC_MODEL}}"
      [ -n "${ANTHROPIC_BASE_URL:-}" ] || die "ANTHROPIC_BASE_URL is empty in pipeline/.env.steyg"
      [ -n "${ANTHROPIC_AUTH_TOKEN:-}" ] || die "ANTHROPIC_AUTH_TOKEN is empty in pipeline/.env.steyg"
      [ -n "$scene" ] && [ -n "$guess" ] || die "set ANTHROPIC_DEFAULT_SONNET_MODEL and ANTHROPIC_DEFAULT_HAIKU_MODEL in pipeline/.env.steyg"
      printf 'CLAUDE_BASE_URL=%s\nCLAUDE_AUTH_TOKEN=%s\nCLAUDE_SCENE_MODEL=%s\nCLAUDE_GUESS_MODEL=%s\n' \
        "$ANTHROPIC_BASE_URL" "$ANTHROPIC_AUTH_TOKEN" "$scene" "$guess"
    )
  else
    [ -f .env ] || die "pipeline/.env is missing"
    grep -qE '^CLAUDE_BASE_URL=.+' .env || die "no gateway: create pipeline/.env.steyg, or set CLAUDE_BASE_URL in pipeline/.env"
    grep -qE '^CLAUDE_AUTH_TOKEN=.+' .env || die "set CLAUDE_AUTH_TOKEN in pipeline/.env first"
    grep -E '^CLAUDE_[A-Z_]+=' .env
  fi
}

# Writes pipeline/.env.steyg with the STEYG address and models filled in; asks only for the token (hidden while
# typing). Does nothing when the file already exists. Re-create: rm pipeline/.env.steyg, then 'steyg'.
ensure_steyg() {
  [ -f .env.steyg ] && return
  [ -t 0 ] || die "pipeline/.env.steyg is missing: run 'pipeline/scripts/media-ai-on-vps.sh steyg' in a terminal"
  step "Create pipeline/.env.steyg (git-ignored): paste your STEYG token (sk-steyg-...), then Enter"
  read -rs -p "STEYG token: " token; echo
  case "$token" in sk-*) ;; *) die "that does not look like a STEYG token (it starts with sk-); nothing was written" ;; esac
  umask 077
  cat > .env.steyg <<EOF
# TEMPORARY (TASK-115): STEYG keys for media-ai on the VPS. Git-ignored; delete after the run.
export ANTHROPIC_BASE_URL="https://steyg.one/api"
export ANTHROPIC_AUTH_TOKEN="$token"
export ANTHROPIC_MODEL="claude-haiku-4-5"
export ANTHROPIC_DEFAULT_OPUS_MODEL="claude-opus-5-5"
export ANTHROPIC_DEFAULT_SONNET_MODEL="claude-opus-5-5"   # media-ai scene writer
export ANTHROPIC_DEFAULT_HAIKU_MODEL="claude-haiku-4-5"   # media-ai picture checks (must read images)
# export STEYG_SCENE_MODEL="claude-haiku-4-5"             # uncomment to use another scene model
EOF
  umask 022
  echo "Saved pipeline/.env.steyg"
}

case "${1:-}" in
  steyg)     # create pipeline/.env.steyg, asking only for the token
    ensure_steyg
    ;;
  gateway)   # print what 'setup' will send, with the token hidden (no ssh, no call)
    ensure_steyg
    gateway_lines | sed -E 's/^(CLAUDE_AUTH_TOKEN=.{0,9}).*/\1…(hidden)/'
    ;;
  setup)
    [ -f .env ] && grep -qE '^CLAUDE_BASE_URL=.+' .env || ensure_steyg
    lines="$(gateway_lines)"
    check_ssh
    step "Copy the pipeline code to $VPS:$REMOTE_DIR (no data, no .env)"
    ssh "$VPS" "mkdir -p $REMOTE_DIR"
    rsync -a --delete --exclude .venv --exclude data --exclude '.env*' --exclude gateway.env --exclude __pycache__ \
      ./ "$VPS:$REMOTE_DIR/"
    step "Send only the gateway keys (CLAUDE_*)"
    printf '%s\n' "$lines" | ssh "$VPS" "umask 077 && cat > $REMOTE_DIR/gateway.env"
    remote setup
    ;;
  start|status|stop)
    check_ssh
    remote "$1"
    ;;
  link)
    check_ssh
    remote link
    step "Export the bundled dictionary on this Mac (needs the Postgres tunnel, like 'count')"
    uv run pipeline export
    echo "Next: check a sample in the admin 'Media to review' chip, then build the app (TASK-115.5)."
    ;;
  *) sed -n '2,17p' "$0"; exit 1 ;;
esac
