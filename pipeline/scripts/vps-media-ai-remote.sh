#!/usr/bin/env bash
# TASK-115: the VPS half of media-ai-on-vps.sh. Do not start it by hand: the Mac script copies the pipeline to
# ~/saynata-pipeline/pipeline on the server and calls this file there with one of: setup, start, status, stop, link.
#
# Claude calls go through the gateway in pipeline/gateway.env (CLAUDE_BASE_URL, for example STEYG with DeepSeek);
# Codex draws with the server's ChatGPT login (/var/lib/saynata/codex, the one the admin uses for AI pictures).
# Pictures are drawn into data/media here and copied to /var/lib/saynata/media by "link".
# Safe to run again: "start" continues where it stopped (progress is in Postgres), "link" links only new pictures.
set -euo pipefail

cd "$(dirname "$0")/.."   # ~/saynata-pipeline/pipeline
export PATH="$HOME/.local/bin:$PATH"
export UV_PYTHON=3.12   # the project's Python; uv picks the newest (3.15) otherwise, and onnxruntime has no 3.15 build

CODEX_VERSION=0.163.0                                   # the same pinned version as backend/Dockerfile
CODEX_DIR="${CODEX_HOST_DIR:-/var/lib/saynata/codex}"
SERVER_MEDIA="${MEDIA_HOST_DIR:-/var/lib/saynata/media}"
BACKEND_ENV="${BACKEND_ENV:-}"   # found by find_backend_env when empty
APP_UID=10001                                           # the backend container user
MAX_COST="${MAX_COST:-40}"
WORKERS="${WORKERS:-4}"
LOG=data/out/media-ai-run.log
PIDFILE=data/out/media-ai-run.pid
export CODEX_HOME="$CODEX_DIR"

SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo"
step() { printf '\n==> %s\n' "$*"; }
die()  { printf 'Stopped: %s\n' "$*" >&2; exit 1; }
running() { [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; }
env_value() { grep -E "^$1=" "$2" 2>/dev/null | tail -1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//'; }

# Files Codex or this script create as root must stay usable by the backend container (uid 10001).
give_back() {
  [ "$(id -u)" -eq 0 ] && chown -R "$APP_UID:$APP_UID" "$CODEX_DIR" || true
}

# backend/.env holds DB_PASSWORD. Found by itself: the folder docker compose started Postgres from, then the usual
# places (doc-11 uses /var/www/saynata, the deploy workflow ~/saynata), then any backend/.env under /var/www, /srv, /opt, ~.
find_backend_env() {
  [ -n "$BACKEND_ENV" ] && { [ -f "$BACKEND_ENV" ] || die "BACKEND_ENV=$BACKEND_ENV is missing"; return; }
  local dir candidate
  if command -v docker >/dev/null; then
    for id in $($SUDO docker ps -q --filter label=com.docker.compose.service=postgres 2>/dev/null); do
      dir="$($SUDO docker inspect -f '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}' "$id" 2>/dev/null || true)"
      [ -n "$dir" ] && [ -f "$dir/.env" ] && grep -q '^DB_PASSWORD=' "$dir/.env" && { BACKEND_ENV="$dir/.env"; break; }
    done
  fi
  if [ -z "$BACKEND_ENV" ]; then
    for candidate in /var/www/saynata/backend/.env "$HOME/saynata/backend/.env" /srv/saynata/backend/.env \
                     /opt/saynata/backend/.env \
                     $(find /var/www /srv /opt "$HOME" -maxdepth 4 -path '*/backend/.env' 2>/dev/null); do
      [ -f "$candidate" ] && grep -q '^DB_PASSWORD=' "$candidate" && { BACKEND_ENV="$candidate"; break; }
    done
  fi
  [ -n "$BACKEND_ENV" ] || die "no backend/.env with DB_PASSWORD found on this server (looked in docker, /var/www, /srv, /opt, ~)"
  echo "backend/.env: $BACKEND_ENV"
}

setup() {
  mkdir -p data/out data/media
  [ -f gateway.env ] || die "gateway.env is missing (the Mac script sends it)"
  [ -n "$(env_value CLAUDE_BASE_URL gateway.env)" ] || die "CLAUDE_BASE_URL is empty in the Mac's pipeline/.env"
  find_backend_env
  [ -d "$CODEX_DIR" ] || die "$CODEX_DIR is missing: the server has no Codex login"

  step "1/6 uv"
  command -v uv >/dev/null || curl -LsSf https://astral.sh/uv/install.sh | sh
  uv --version

  step "2/6 Codex CLI $CODEX_VERSION"
  if ! command -v codex >/dev/null; then
    case "$(uname -m)" in x86_64) arch=x86_64 ;; aarch64|arm64) arch=aarch64 ;; *) die "no Codex build for $(uname -m)" ;; esac
    mkdir -p "$HOME/.local/bin"
    for bin in codex codex-code-mode-host; do
      curl -fsSL "https://github.com/openai/codex/releases/download/rust-v${CODEX_VERSION}/${bin}-${arch}-unknown-linux-musl.tar.gz" \
        | tar -xz -C "$HOME/.local/bin"
      mv "$HOME/.local/bin/${bin}-${arch}-unknown-linux-musl" "$HOME/.local/bin/$bin"
      chmod 755 "$HOME/.local/bin/$bin"
    done
  fi
  codex --version

  step "3/6 Codex login (shared with the admin's AI pictures)"
  if [ "$(id -u)" -ne 0 ]; then
    command -v setfacl >/dev/null || $SUDO apt-get install -y acl >/dev/null
    $SUDO setfacl -R -m "u:$(id -un):rwX" -m "d:u:$(id -un):rwX" "$CODEX_DIR"
  fi
  codex login status || die "Codex on the server is not signed in. Sign in once (doc-15, TASK-91), then run setup again."
  give_back

  step "4/6 pipeline/.env (Postgres on this server + the gateway)"
  password="$(env_value DB_PASSWORD "$BACKEND_ENV" || true)"
  [ -n "$password" ] || die "DB_PASSWORD is empty in $BACKEND_ENV"
  port="$(env_value POSTGRES_PORT "$BACKEND_ENV" || true)"
  umask 077
  {
    echo "DATABASE_URL=postgresql://app:${password}@127.0.0.1:${port:-5432}/english_translation"
    echo "MEDIA_BASE_URL=$(env_value MEDIA_BASE_URL "$BACKEND_ENV" || true)"
    cat gateway.env
  } | grep -v '^MEDIA_BASE_URL=$' > .env
  umask 022

  step "5/6 Python packages"
  uv sync --quiet

  step "6/6 Checks: the gateway reads pictures, and what the run would cost"
  uv run python - <<'PY'
import base64, io
from dotenv import load_dotenv
load_dotenv(".env")
from PIL import Image
from pipeline import llm, media_ai
model = llm.model(media_ai.GUESS_MODEL, "CLAUDE_GUESS_MODEL")
buffer = io.BytesIO(); Image.new("RGB", (64, 64), (220, 20, 20)).save(buffer, "JPEG")
image = {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg",
                                     "data": base64.b64encode(buffer.getvalue()).decode()}}
reply = llm.client().messages.create(model=model, max_tokens=20, messages=[{"role": "user", "content": [
    image, {"type": "text", "text": "What colour fills this picture? Answer with one word."}]}])
answer = "".join(getattr(block, "text", "") for block in reply.content).strip().lower()
print(f"guess model {model}: '{answer}'")
if "red" not in answer:
    raise SystemExit(f"Stopped: {model} cannot read pictures. Set STEYG_GUESS_MODEL in the Mac's pipeline/.env.steyg "
                     "(or CLAUDE_GUESS_MODEL in pipeline/.env) to a gateway model that reads images, then run setup again.")
print(f"scene model {llm.model(media_ai.SCENE_MODEL, 'CLAUDE_SCENE_MODEL')}")
PY
  uv run pipeline media-ai --all --dry-run --workers "$WORKERS" --max-cost "$MAX_COST"
  echo "Setup done. Next: the Mac script's 'start'."
}

start() {
  running && { echo "Already running (pid $(cat "$PIDFILE")). Use 'status'."; return; }
  [ -f .env ] || die "run setup first"
  mkdir -p data/out
  step "Starting the run in the background (log: $PWD/$LOG)"
  nohup setsid bash -c "
    set -u
    export PATH='$HOME/.local/bin':\"\$PATH\" CODEX_HOME='$CODEX_DIR'
    ( while sleep 1800; do find '$CODEX_DIR/generated_images' -name '*.png' -mmin +60 -delete 2>/dev/null; done ) &
    echo \"== \$(date -u) bundled words\"
    if uv run pipeline media-ai --all --workers $WORKERS --max-cost $MAX_COST --report data/out/media-ai.html \\
       && echo \"== \$(date -u) backend words\" \\
       && uv run pipeline media-ai --backend --all --workers $WORKERS --max-cost $MAX_COST --report data/out/media-ai-backend.html
    then echo \"== \$(date -u) FINISHED (or stopped at the cap/plan limit: run start again to continue)\"
    else echo \"== \$(date -u) STOPPED WITH AN ERROR (see above); fix it, then start again\"
    fi
    [ \"\$(id -u)\" -eq 0 ] && chown -R $APP_UID:$APP_UID '$CODEX_DIR'
    kill 0
  " >> "$LOG" 2>&1 < /dev/null &
  echo $! > "$PIDFILE"
  echo "Started (pid $!). You can close the Mac now."
}

status() {
  if running; then echo "RUNNING (pid $(cat "$PIDFILE"))"; else echo "NOT RUNNING"; fi
  [ -f "$LOG" ] && { echo "--- last lines of $LOG"; tail -n 15 "$LOG"; } || echo "No log yet."
}

stop() {
  running || { echo "Not running."; return; }
  kill -- "-$(cat "$PIDFILE")" 2>/dev/null || kill "$(cat "$PIDFILE")"
  give_back
  echo "Stopped. 'start' continues where it stopped."
}

link() {
  running && die "the run is still going; wait for it or 'stop' it first"
  step "1/3 Copy new pictures to $SERVER_MEDIA"
  $SUDO rsync -a --ignore-existing data/media/ "$SERVER_MEDIA/"
  $SUDO chown -R "$APP_UID:$APP_UID" "$SERVER_MEDIA"
  step "2/3 Link bundled words"
  uv run pipeline media-ai --link
  step "3/3 Link backend words"
  uv run pipeline media-ai --backend --link
  give_back
  echo "Linked. Failed senses: data/out/media-ai.html and data/out/media-ai-backend.html on the server."
}

case "${1:-}" in
  setup|start|status|stop|link) "$1" ;;
  *) die "use: setup | start | status | stop | link" ;;
esac
