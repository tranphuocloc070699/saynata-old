#!/usr/bin/env bash
# TASK-115: draw the AI pictures on the VPS, so the Mac can sleep. Claude calls go through STEYG (Claude models,
# keys in pipeline/.env.steyg); Codex draws with the server's ChatGPT login.
#
# Run it on the Mac, from anywhere in the repo. Usually only two commands:
#   pipeline/scripts/media-ai-on-vps.sh          # everything: the key file, VPS setup and checks, then start the run
#   pipeline/scripts/media-ai-on-vps.sh link     # after the run: copy, link, then export the app bundle here
# The first time, it writes pipeline/.env.steyg with everything filled in except the token and stops: paste the
# token there, then run it again. Other steps, when needed:
#   status   running or not, the last log lines        stop   stop it; running again continues where it stopped
#   setup    only the VPS setup and checks             start  only start the run
#
# Safe to run again: every step checks first and continues where it stopped. Old Pixabay rows and files are kept.
# Settings (env): VPS (ssh host, default vps_sieutoc), MAX_COST (USD cap per pass, default 40), WORKERS (default 4).
set -euo pipefail
# Works from the repo root (pipeline/scripts/media-ai-on-vps.sh) or from pipeline/ (scripts/media-ai-on-vps.sh).

VPS="${VPS:-vps_sieutoc}"
REMOTE_DIR='~/saynata-pipeline/pipeline'

cd "$(dirname "$0")/.."   # pipeline/
step() { printf '\n==> %s\n' "$*"; }
die()  { printf 'Stopped: %s\n' "$*" >&2; exit 1; }
# -t (a terminal) only for setup, where the Codex sign-in prints a code. Never for start: when ssh -t closes, the
# server ends that terminal and kills a background run that has not detached yet (2026-11-04: the run died at once).
# Every command first sends the current VPS script, so a fix reaches the server without a new setup.
# (Safe while a run is going: the run does not read this file again.)
remote() {
  [ "$1" = setup ] || scp -q scripts/vps-media-ai-remote.sh "$VPS:$REMOTE_DIR/scripts/vps-media-ai-remote.sh"
  ssh $( [ "$1" = setup ] && [ -t 0 ] && echo -t ) "$VPS" "MAX_COST='${MAX_COST:-40}' WORKERS='${WORKERS:-4}' $REMOTE_DIR/scripts/vps-media-ai-remote.sh $1"
}
check_ssh() { ssh -o BatchMode=yes -o ConnectTimeout=10 "$VPS" true || die "cannot reach $VPS over ssh"; }

# TEMPORARY (TASK-115): pipeline/.env.steyg (git-ignored) holds the STEYG keys in Claude Code's ANTHROPIC_* form.
# The first run writes it with everything except the token, then stops so the developer can paste the token.
ensure_steyg() {
  if [ ! -f .env.steyg ]; then
    umask 077
    cat > .env.steyg <<'EOF'
# TEMPORARY (TASK-115): STEYG keys for media-ai on the VPS. Git-ignored; delete after the run.
# Fill in ONLY the token (between the quotes). Everything else is already set.
export ANTHROPIC_AUTH_TOKEN=""

export ANTHROPIC_BASE_URL="https://steyg.one/api"
export ANTHROPIC_MODEL="claude-haiku-4-5"
export ANTHROPIC_DEFAULT_OPUS_MODEL="claude-opus-5-5"
export ANTHROPIC_DEFAULT_SONNET_MODEL="claude-sonnet-5-5" # media-ai scene writer (the trial prompts were tuned on Sonnet)
export ANTHROPIC_DEFAULT_HAIKU_MODEL="claude-haiku-4-5"   # media-ai picture checks (must read images)
# export STEYG_SCENE_MODEL="claude-haiku-4-5"             # uncomment to use another scene model
EOF
    umask 022
    step "Wrote pipeline/.env.steyg"
  fi
  token="$(steyg_value ANTHROPIC_AUTH_TOKEN)"
  case "$token" in
    sk-*) ;;
    "") die "the token is empty: put it in pipeline/.env.steyg as  ANTHROPIC_AUTH_TOKEN=sk-steyg-...  then run this again" ;;
    *)  die "the token in pipeline/.env.steyg does not start with sk- (check for extra characters), then run this again" ;;
  esac
}

# One value from pipeline/.env.steyg, written in any form: KEY=v, KEY="v", KEY='v', export KEY=v (Windows line ends ok).
steyg_value() {
  grep -E "^[[:space:]]*(export[[:space:]]+)?$1[[:space:]]*=" .env.steyg | tail -1 | tr -d '\r' \
    | sed -E "s/^[^=]*=[[:space:]]*//; s/[[:space:]]+#.*$//; s/^[\"']//; s/[\"'][[:space:]]*$//; s/[[:space:]]+$//" || true
}

# The gateway keys as CLAUDE_* lines (what pipeline/src/pipeline/llm.py reads). Only the token must be in the file;
# the rest has defaults here. STEYG_SCENE_MODEL / STEYG_GUESS_MODEL win over the SONNET / HAIKU models.
gateway_lines() {
  (
    url="$(steyg_value ANTHROPIC_BASE_URL)"
    sonnet="$(steyg_value ANTHROPIC_DEFAULT_SONNET_MODEL)"; haiku="$(steyg_value ANTHROPIC_DEFAULT_HAIKU_MODEL)"
    scene="$(steyg_value STEYG_SCENE_MODEL)"; guess="$(steyg_value STEYG_GUESS_MODEL)"
    printf 'CLAUDE_BASE_URL=%s\nCLAUDE_AUTH_TOKEN=%s\nCLAUDE_SCENE_MODEL=%s\nCLAUDE_GUESS_MODEL=%s\n' \
      "${url:-https://steyg.one/api}" "$(steyg_value ANTHROPIC_AUTH_TOKEN)" \
      "${scene:-${sonnet:-claude-sonnet-5-5}}" "${guess:-${haiku:-claude-haiku-4-5}}"
  )
}

do_setup() {
  ensure_steyg
  lines="$(gateway_lines)"
  step "Gateway (token hidden)"
  printf '%s\n' "$lines" | sed -E 's/^(CLAUDE_AUTH_TOKEN=.{0,9}).*/\1…(hidden)/'
  check_ssh
  step "Copy the pipeline code to $VPS:$REMOTE_DIR (no data, no .env)"
  ssh "$VPS" "mkdir -p $REMOTE_DIR"
  rsync -a --delete --exclude .venv --exclude data --exclude '.env*' --exclude gateway.env --exclude __pycache__ --exclude .pytest_cache \
    ./ "$VPS:$REMOTE_DIR/"
  step "Send only the gateway keys (CLAUDE_*)"
  printf '%s\n' "$lines" | ssh "$VPS" "umask 077 && cat > $REMOTE_DIR/gateway.env"
  remote setup
}

case "${1:-run}" in
  run)
    do_setup
    step "The paid run starts in 15 seconds (Ctrl+C to cancel; the estimate is above)"
    sleep 15
    remote start
    echo "Check it any time: pipeline/scripts/media-ai-on-vps.sh status"
    ;;
  setup) do_setup ;;
  gateway) ensure_steyg; gateway_lines | sed -E 's/^(CLAUDE_AUTH_TOKEN=.{0,9}).*/\1…(hidden)/' ;;
  start|status|stop) check_ssh; remote "$1" ;;
  link)
    check_ssh
    remote link
    step "Export the bundled dictionary on this Mac (needs the Postgres tunnel, like 'count')"
    uv run pipeline export
    echo "Next: check a sample in the admin 'Media to review' chip, then build the app (TASK-115.5)."
    ;;
  *) sed -n '2,14p' "$0"; exit 1 ;;
esac
