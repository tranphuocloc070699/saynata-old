#!/usr/bin/env bash
# TASK-115: replace every Pixabay picture with an AI picture (TASK-115.4 and 115.5, continues TASK-84).
#
# Run it on the developer's Mac, from anywhere in the repo:
#   pipeline/scripts/replace-pixabay-pictures.sh count   # how many senses still show Pixabay (free, read-only)
#   pipeline/scripts/replace-pixabay-pictures.sh draw    # PAID: Claude about $34 + Codex (ChatGPT plan), about 26 h
#   pipeline/scripts/replace-pixabay-pictures.sh ship    # copy files to the VPS, link them, export the bundle
#
# Safe to run again: "draw" continues where it stopped (progress is in Postgres), "ship" copies only new files
# (rsync --ignore-existing) and links only pictures that are not linked yet. Old Pixabay rows and files are kept.
#
# Settings (env): MAX_COST (Claude cap per draw pass in USD, default 40), WORKERS (default 4),
#                 VPS (ssh host, default vps_sieutoc), MEDIA_DIR on the server (default /var/lib/saynata/media).
set -euo pipefail

MAX_COST="${MAX_COST:-40}"
WORKERS="${WORKERS:-4}"
VPS="${VPS:-vps_sieutoc}"
SERVER_MEDIA="${MEDIA_DIR:-/var/lib/saynata/media}"

cd "$(dirname "$0")/.."   # pipeline/
step() { printf '\n==> %s\n' "$*"; }
die()  { printf 'Stopped: %s\n' "$*" >&2; exit 1; }

env_value() { grep -E "^$1=" .env 2>/dev/null | tail -1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//'; }

check_common() {
  [ -f .env ] || die "pipeline/.env is missing"
  DATABASE_URL="$(env_value DATABASE_URL)"
  [ -n "$DATABASE_URL" ] || die "DATABASE_URL is not set in pipeline/.env"
  command -v uv >/dev/null || die "uv is not installed"
}

count() {
  command -v psql >/dev/null || die "psql is not installed (brew install libpq)"
  step "Senses whose current picture is from Pixabay"
  psql "$DATABASE_URL" -X -q -c "
    SELECT 'bundled words' AS words, count(*) AS pixabay_senses
      FROM dictionary_sense s JOIN media m ON m.id = s.media_id WHERE m.source = 'pixabay'
    UNION ALL
    SELECT 'backend words', count(*)
      FROM word_lookup_media l JOIN media m ON m.id = l.media_id
     WHERE m.source = 'pixabay' AND (l.media_status IS NULL OR l.media_status <> 'removed');"
  echo "Write these numbers in the TASK-115.4 notes before 'draw'."
}

draw() {
  [ -n "${ANTHROPIC_API_KEY:-}$(env_value ANTHROPIC_API_KEY)" ] || die "ANTHROPIC_API_KEY is not set in pipeline/.env"
  command -v codex >/dev/null || die "the Codex CLI is not installed or not signed in"
  awake=()
  command -v caffeinate >/dev/null && awake=(caffeinate -i)

  # Codex keeps a temporary PNG per picture; clean old ones every 30 min while drawing.
  ( while sleep 1800; do find "${CODEX_HOME:-$HOME/.codex}/generated_images" -name '*.png' -mmin +60 -delete 2>/dev/null || true; done ) &
  cleaner=$!
  trap 'kill $cleaner 2>/dev/null || true' EXIT

  step "1/2 Bundled words: media-ai --all (cap \$$MAX_COST, $WORKERS workers)"
  "${awake[@]}" uv run pipeline media-ai --all --workers "$WORKERS" --max-cost "$MAX_COST" --report data/out/media-ai.html
  step "2/2 Backend words: media-ai --backend --all (cap \$$MAX_COST)"
  "${awake[@]}" uv run pipeline media-ai --backend --all --workers "$WORKERS" --max-cost "$MAX_COST" \
    --report data/out/media-ai-backend.html
  echo "Done or stopped at the cap/plan limit. Run 'draw' again to continue; then 'ship'."
  echo "Failed senses: data/out/media-ai.html and data/out/media-ai-backend.html (hand upload or image_type none)."
}

ship() {
  [ -d data/media ] || die "data/media is missing: nothing to copy"
  ssh -o BatchMode=yes -o ConnectTimeout=10 "$VPS" true || die "cannot reach $VPS over ssh"
  step "1/4 Copy new pictures to $VPS:$SERVER_MEDIA"
  rsync -a --ignore-existing data/media/ "$VPS:$SERVER_MEDIA/"
  ssh "$VPS" "chown -R 10001:10001 '$SERVER_MEDIA'"
  step "2/4 Link bundled words"
  uv run pipeline media-ai --link
  step "3/4 Link backend words"
  uv run pipeline media-ai --backend --link
  step "4/4 Export the bundled dictionary for the next app build"
  uv run pipeline export
  echo "Next: check a sample in the admin 'Media to review' chip, then build the app (TASK-115.5)."
}

case "${1:-}" in
  count) check_common; count ;;
  draw)  check_common; draw ;;
  ship)  check_common; ship ;;
  *) sed -n '2,13p' "$0"; exit 1 ;;
esac
