#!/usr/bin/env bash
# TASK-115: draw the AI pictures on the VPS, so the Mac can sleep. Claude calls go through the gateway
# (CLAUDE_BASE_URL in pipeline/.env, for example STEYG with DeepSeek); Codex draws with the server's ChatGPT login.
#
# Run it on the Mac, from anywhere in the repo:
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

ssh -o BatchMode=yes -o ConnectTimeout=10 "$VPS" true || die "cannot reach $VPS over ssh"

case "${1:-}" in
  setup)
    [ -f .env ] || die "pipeline/.env is missing"
    grep -qE '^CLAUDE_BASE_URL=.+' .env || die "set CLAUDE_BASE_URL (and CLAUDE_AUTH_TOKEN) in pipeline/.env first"
    grep -qE '^CLAUDE_AUTH_TOKEN=.+' .env || die "set CLAUDE_AUTH_TOKEN in pipeline/.env first"
    step "Copy the pipeline code to $VPS:$REMOTE_DIR (no data, no .env)"
    ssh "$VPS" "mkdir -p $REMOTE_DIR"
    rsync -a --delete --exclude .venv --exclude data --exclude .env --exclude gateway.env --exclude __pycache__ \
      ./ "$VPS:$REMOTE_DIR/"
    step "Send only the gateway keys (CLAUDE_*)"
    grep -E '^CLAUDE_[A-Z_]+=' .env | ssh "$VPS" "umask 077 && cat > $REMOTE_DIR/gateway.env"
    remote setup
    ;;
  start|status|stop)
    remote "$1"
    ;;
  link)
    remote link
    step "Export the bundled dictionary on this Mac (needs the Postgres tunnel, like 'count')"
    uv run pipeline export
    echo "Next: check a sample in the admin 'Media to review' chip, then build the app (TASK-115.5)."
    ;;
  *) sed -n '2,14p' "$0"; exit 1 ;;
esac
