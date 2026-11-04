#!/usr/bin/env bash
# TASK-115: the VPS half of media-ai-on-vps.sh. Do not start it by hand: the Mac script copies the pipeline to
# ~/saynata-pipeline/pipeline on the server and calls this file there with one of: setup, start, status, stop, link.
#
# Claude calls go through the gateway in pipeline/gateway.env (CLAUDE_BASE_URL, for example STEYG with DeepSeek);
# Codex draws with the pipeline's own ChatGPT login (~/.codex-pipeline; setup signs in with a device code once).
# Pictures are drawn into data/media here and copied to /var/lib/saynata/media by "link".
# Safe to run again: "start" continues where it stopped (progress is in Postgres), "link" links only new pictures.
set -euo pipefail

cd "$(dirname "$0")/.."   # ~/saynata-pipeline/pipeline
export PATH="$HOME/.local/bin:$PATH"
export UV_PYTHON=3.12   # the project's Python; uv picks the newest (3.15) otherwise, and onnxruntime has no 3.15 build

CODEX_VERSION=0.163.0                                   # the same pinned version as backend/Dockerfile
CODEX_DIR="${PIPELINE_CODEX_HOME:-$HOME/.codex-pipeline}"   # its OWN login: sharing the admin's (/var/lib/saynata/codex)
                                                           # broke both, a refresh token works only once
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
  mkdir -p data/out data/media "$CODEX_DIR"
  [ -f gateway.env ] || die "gateway.env is missing (the Mac script sends it)"
  [ -n "$(env_value CLAUDE_BASE_URL gateway.env)" ] || die "CLAUDE_BASE_URL is empty in the Mac's pipeline/.env"
  find_backend_env

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

  step "3/6 Codex login for the pipeline only ($CODEX_DIR, not the admin's)"
  mkdir -p "$CODEX_DIR"; chmod 700 "$CODEX_DIR"
  # One tiny real call; its output is kept in $CODEX_TRY so a failure shows Codex's own words.
  CODEX_TRY="$(mktemp)"
  codex_try() {
    # Judged by the exit code (no pipe into grep -q: with pipefail that kills codex mid-write and looks like a failure).
    local rc=0
    (cd "$(mktemp -d)" && timeout 180 codex exec --skip-git-repo-check --sandbox read-only "Reply with the word OK." \
       </dev/null >"$CODEX_TRY" 2>&1) || rc=$?
    [ "$rc" -eq 0 ] && ! grep -qiE 'unauthorized|refresh token|sign in again' "$CODEX_TRY"
  }
  login_problem() {  # sign in again only when the problem is the login itself
    ! codex login status >/dev/null 2>&1 \
      || grep -qiE 'sign in again|refresh token|not logged in|unauthorized' "$CODEX_TRY"
  }
  if ! codex_try; then
    if login_problem; then
      echo "Sign in to Codex with your ChatGPT account: open the link below on your Mac or phone and type the code."
      codex logout >/dev/null 2>&1 || true
      codex login --device-auth
      codex_try && { echo "Codex answers."; rm -f "$CODEX_TRY"; return_ok=1; } || true
    fi
    if [ -z "${return_ok:-}" ]; then
      echo "--- what Codex said (last 25 lines):"; tail -n 25 "$CODEX_TRY"
      die "Codex is signed in but does not answer (see above). Send this output; the login is kept."
    fi
  fi
  [ -n "${return_ok:-}" ] || echo "Codex answers."; rm -f "$CODEX_TRY"

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

  step "6/6 Checks: the models the gateway has, a picture test, and what the run would cost"
  uv run python - <<'PY'
# Picks the models from what the gateway really offers (GET /v1/models): the configured one when it is there,
# else the closest Claude model. The guess model must pass a picture test (a red square -> "red").
# The picks are written into pipeline/.env, so the run uses them.
import base64, io, re
from pathlib import Path
from dotenv import load_dotenv
load_dotenv(".env")
from PIL import Image
from pipeline import llm, media_ai

client = llm.client()
want_scene = llm.model(media_ai.SCENE_MODEL, "CLAUDE_SCENE_MODEL")
want_guess = llm.model(media_ai.GUESS_MODEL, "CLAUDE_GUESS_MODEL")
try:
    offered = [m.id for m in client.models.list()]
except Exception as error:  # a gateway without the list: keep the configured models
    print(f"(the gateway did not list its models: {error}; trying the configured ones)")
    offered = []
if offered:
    print("the gateway offers: " + ", ".join(sorted(offered)))

def ranked(want: str, order: list[str]) -> list[str]:
    """The wanted model first (when offered or when nothing is listed), then Claude models by family order."""
    if not offered:
        return [want]
    def rank(name: str) -> tuple:
        family = next((i for i, f in enumerate(order) if f in name), len(order))
        version = [-int(n) for n in re.findall(r"\d+", name)]  # newest first
        return (0 if "claude" in name else 1, family, version)
    same = lambda a, b: re.sub(r"[.\-_ ]", "", a.lower()) == re.sub(r"[.\-_ ]", "", b.lower())
    match = [m for m in offered if same(m, want)]  # claude-opus-5-5 is the gateway's claude-opus-5.5
    return match + sorted((m for m in offered if m not in match), key=rank)

buffer = io.BytesIO(); Image.new("RGB", (64, 64), (220, 20, 20)).save(buffer, "JPEG")
image = {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg",
                                     "data": base64.b64encode(buffer.getvalue()).decode()}}

def reads_pictures(model: str) -> bool:
    try:
        reply = client.messages.create(model=model, max_tokens=20, messages=[{"role": "user", "content": [
            image, {"type": "text", "text": "What colour fills this picture? Answer with one word."}]}])
    except Exception as error:
        print(f"  {model}: {str(error)[:120]}")
        return False
    answer = "".join(getattr(block, "text", "") for block in reply.content).strip().lower()
    print(f"  {model}: '{answer}'")
    return "red" in answer

print("picture test (cheapest first):")
guess = next((m for m in ranked(want_guess, ["haiku", "sonnet", "opus"])[:6] if reads_pictures(m)), None)
if not guess:
    raise SystemExit("Stopped: no gateway model passed the picture test. Pick one from the list above and set "
                     "STEYG_GUESS_MODEL in the Mac's pipeline/.env.steyg, then run again.")
scene = ranked(want_scene, ["sonnet", "opus", "haiku"])[0]

env = Path(".env")
lines = [l for l in env.read_text().splitlines() if not l.startswith(("CLAUDE_SCENE_MODEL=", "CLAUDE_GUESS_MODEL="))]
env.write_text("\n".join(lines + [f"CLAUDE_SCENE_MODEL={scene}", f"CLAUDE_GUESS_MODEL={guess}"]) + "\n")
for role, wanted, got in (("scene", want_scene, scene), ("guess", want_guess, guess)):
    print(f"{role} model: {got}" + ("" if got == wanted else f"   (instead of {wanted}, which the gateway does not offer)"))
PY
  uv run pipeline media-ai --all --dry-run --workers "$WORKERS" --max-cost "$MAX_COST"
  echo "Setup done. Next: the Mac script's 'start'."
}

start() {
  running && { echo "Already running (pid $(cat "$PIDFILE")). Use 'status'."; return; }
  [ -f .env ] || die "run setup first"
  mkdir -p data/out
  step "Starting the run in the background (log: $PWD/$LOG)"
  printf '\n== %s new run started\n' "$(date -u)" >> "$LOG"   # \n first: an old last line may lack one
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
    kill 0
  " >> "$LOG" 2>&1 < /dev/null &
  echo $! > "$PIDFILE"
  sleep 5   # a run that dies at once (bad .env, ssh hang-up) shows here, not hours later
  running || { echo "--- last lines of $LOG"; tail -n 15 "$LOG"; die "the run stopped right after starting (see above)"; }
  echo "Started (pid $(cat "$PIDFILE")), still running after 5 s. You can close the Mac now."
}

status() {
  if running; then echo "RUNNING (pid $(cat "$PIDFILE"))"; else echo "NOT RUNNING"; fi
  [ -f "$LOG" ] || { echo "No log yet."; return; }
  # Only the latest run: from the last "new run started" line on (older runs stay in the file, out of sight).
  echo "--- this run (log: $PWD/$LOG)"
  # (an old run may have left its last line without a line break, so the marker can sit at the end of that line)
  awk '/new run started/ { n = NR; sub(/.*== /, "== ") } { line[NR] = $0 } END { for (i = (n ? n : 1); i <= NR; i++) print line[i] }' "$LOG" \
    | tail -n 15
  done_count="$(awk '/new run started/ { c = 0; next } /^\[[0-9]+\/[0-9]+\]/ { c++ } END { print c + 0 }' "$LOG")"
  passed="$(awk '/new run started/ { c = 0; next } /^\[[0-9]+\/[0-9]+\].*: passed/ { c++ } END { print c + 0 }' "$LOG")"
  echo "--- this run so far: $done_count senses done, $passed passed"
}

stop() {
  running || { echo "Not running."; return; }
  kill -- "-$(cat "$PIDFILE")" 2>/dev/null || kill "$(cat "$PIDFILE")"
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
  echo "Linked. Failed senses: data/out/media-ai.html and data/out/media-ai-backend.html on the server."
}

case "${1:-}" in
  setup|start|status|stop|link) "$1" ;;
  *) die "use: setup | start | status | stop | link" ;;
esac
