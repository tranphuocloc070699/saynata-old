#!/usr/bin/env bash
# Run the whole Saynata stack on this Mac, on the data copied by backend/scripts/pull-from-vps.sh (doc-11, section 20).
#   scripts/run-local.sh          # start everything (or what is not running yet), on localhost only
#   LAN=1 scripts/run-local.sh    # also reachable from your iPhone on the same Wi-Fi (backend + media)
#   scripts/run-local.sh status   # what runs, on which port
#   scripts/run-local.sh stop     # stop everything (the database data stays in the Docker volume)
#
# What runs where:
#   Postgres  127.0.0.1:5433  Docker (backend/compose.yaml), data in the volume "saynata-pgdata"
#   media     :8090/media     python http.server on backend/local-data/media (Caddy does this on the VPS)
#   backend   :8081           ./mvnw spring-boot:run, secrets from backend/.env
#   admin     :5173           Vite, talks to http://localhost:8081
#   web       :3000           Next.js, its /api goes to http://localhost:8081
# Logs: backend/local-data/logs/<name>.log. Safe to run again: running parts are left alone.
set -euo pipefail

cd "$(dirname "$0")/.."    # the repo root
root="$PWD"
data="$root/backend/local-data"
logs="$data/logs"
pids="$data/pids"
mkdir -p "$logs" "$pids"
log() { echo "[$(date +%H:%M:%S)] $*"; }

# Default: only this Mac can reach the services. LAN=1 opens backend and media to the Wi-Fi, for the phone.
if [ "${LAN:-0}" = "1" ]; then
  bind="0.0.0.0"
  host="$(ipconfig getifaddr en0 2>/dev/null || true)"
  [ -n "$host" ] || { log "LAN=1 but no Wi-Fi address found (en0)."; exit 1; }
else
  bind="127.0.0.1"
  host="localhost"
fi

running() { [ -f "$pids/$1.pid" ] && kill -0 "$(cat "$pids/$1.pid")" 2>/dev/null; }

start() {   # start <name> <folder> <command...>
  local name="$1" dir="$2"; shift 2
  if running "$name"; then log "$name already runs (pid $(cat "$pids/$name.pid"))"; return; fi
  log "Starting $name (log: backend/local-data/logs/$name.log)"
  # exec: the saved pid is the program itself. The redirects free this terminal, so the script returns.
  (cd "$dir" && exec nohup "$@") >"$logs/$name.log" 2>&1 </dev/null &
  echo $! >"$pids/$name.pid"
}

stop_one() {
  local name="$1"
  if running "$name"; then
    # mvnw, npm and next start child processes; stop those first.
    pkill -TERM -P "$(cat "$pids/$name.pid")" 2>/dev/null || true
    kill "$(cat "$pids/$name.pid")" 2>/dev/null || true
    log "Stopped $name"
  fi
  rm -f "$pids/$name.pid"
}

case "${1:-start}" in
  start)
    docker info >/dev/null 2>&1 || { log "Docker is not running. Start it: colima start"; exit 1; }
    [ -d "$data/media" ] || { log "No local data yet. Run first: backend/scripts/pull-from-vps.sh"; exit 1; }
    for dir in admin web; do
      [ -d "$dir/node_modules" ] || { log "Installing $dir packages"; (cd "$dir" && npm ci); }
    done

    log "Starting Postgres (127.0.0.1:5433)"
    docker compose -f backend/compose.yaml up -d postgres >/dev/null

    start media "$data" python3 -m http.server 8090 --bind "$bind"
    # Real env variables win over backend/.env, so only the local addresses are set here.
    start backend backend env \
      SERVER_ADDRESS="$bind" \
      MEDIA_DIR="$data/media" \
      MEDIA_BASE_URL="http://$host:8090/media" \
      PUBLIC_BASE_URL="http://$host:8081" \
      ./mvnw -q spring-boot:run
    start admin admin env VITE_API_URL="http://localhost:8081" npm run dev -- --host 127.0.0.1 --port 5173 --strictPort
    start web web env SAYNATA_API_ORIGIN="http://localhost:8081" npm run dev -- --hostname 127.0.0.1 --port 3000

    log "Waiting for the backend (the first start compiles, up to 3 minutes)"
    for _ in $(seq 1 180); do
      curl -fsS -o /dev/null http://localhost:8081/actuator/health 2>/dev/null && break
      running backend || { log "The backend stopped. Last lines of its log:"; tail -20 "$logs/backend.log"; exit 1; }
      sleep 1
    done
    "$0" status
    ;;
  stop)
    for name in web admin backend media; do stop_one "$name"; done
    docker compose -f backend/compose.yaml stop postgres >/dev/null && log "Stopped Postgres (data kept)"
    ;;
  status)
    check() { if curl -fsS -o /dev/null -m 3 "$2" 2>/dev/null; then echo "  up    $1  $2"; else echo "  DOWN  $1  $2"; fi; }
    check "backend" "http://localhost:8081/actuator/health"
    check "media  " "http://localhost:8090/media/"
    check "admin  " "http://localhost:5173/"
    check "web    " "http://localhost:3000/"
    echo "  Postgres: $(docker compose -f backend/compose.yaml ps --format '{{.Status}}' postgres 2>/dev/null || echo unknown)"
    ;;
  *) echo "Usage: $0 [start|stop|status]"; exit 1 ;;
esac
