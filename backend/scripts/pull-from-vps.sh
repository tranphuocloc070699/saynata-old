#!/usr/bin/env bash
# Copy the live data from the VPS to this Mac, so the whole stack runs locally (guide: doc-11, section 20).
# Run ON THE MAC, from anywhere:   backend/scripts/pull-from-vps.sh
#   VPS_HOST=other_host backend/scripts/pull-from-vps.sh   # another SSH host name (default: vps_sieutoc)
#   FORCE=1 backend/scripts/pull-from-vps.sh                # replace a local database that already has data
#
# Steps: 1. pg_dump on the VPS, streamed to backend/local-data/dumps/
#        2. rsync the media folder to backend/local-data/media/
#        3. copy the server .env to backend/local-data/vps.env (secrets: chmod 600, git-ignored)
#        4. start the local Postgres (compose.yaml, Docker volume "saynata-pgdata") and pg_restore the dump
#        5. print the row count of every table on the VPS and locally, side by side
# Safe to run again: it only reads from the VPS, and it stops before touching a local database with data unless FORCE=1.
set -euo pipefail

cd "$(dirname "$0")/.."    # the backend/ folder
VPS_HOST="${VPS_HOST:-vps_sieutoc}"
REMOTE_DIR="/var/www/saynata/backend"
DATA_DIR="local-data"
log() { echo "[$(date +%H:%M:%S)] $*"; }

# --- Checks before anything changes --------------------------------------------------------------------
for tool in ssh rsync docker; do
  command -v "$tool" >/dev/null || { log "Missing tool: $tool"; exit 1; }
done
docker info >/dev/null 2>&1 || { log "Docker is not running. Start it: colima start"; exit 1; }
ssh -o BatchMode=yes -o ConnectTimeout=10 "$VPS_HOST" true \
  || { log "Cannot SSH to $VPS_HOST. Check ~/.ssh/config."; exit 1; }
media_dir="$(ssh "$VPS_HOST" "grep -E '^MEDIA_HOST_DIR=' $REMOTE_DIR/.env | cut -d= -f2-" || true)"
media_dir="${media_dir:-/var/lib/saynata/media}"

mkdir -p "$DATA_DIR/dumps" "$DATA_DIR/media"
compose_local="docker compose -f compose.yaml"
remote_psql="cd $REMOTE_DIR && docker compose -f docker-compose.prod.yml exec -T postgres"

# Row counts of every table, one "table|rows" line each. Same query as restore.sh.
count_sql="SELECT table_name, (xpath('/row/c/text()', query_to_xml(format('SELECT count(*) AS c FROM public.%I', table_name), false, true, '')))[1]::text FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE' ORDER BY table_name;"

# A local database that already has tables is not replaced without FORCE=1.
$compose_local up -d postgres >/dev/null
for _ in $(seq 1 60); do
  $compose_local exec -T postgres pg_isready -U app -d english_translation >/dev/null 2>&1 && break
  sleep 1
done
$compose_local exec -T postgres pg_isready -U app -d english_translation >/dev/null || { log "Local Postgres did not start."; exit 1; }
local_tables="$($compose_local exec -T postgres psql -U app -d english_translation -tAc \
  "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public'")"
if [ "$local_tables" != "0" ] && [ "${FORCE:-0}" != "1" ]; then
  log "The local database already has $local_tables tables. Run again with FORCE=1 to replace them."
  exit 1
fi

# --- 1. Database dump ----------------------------------------------------------------------------------
stamp="$(date +%Y%m%d-%H%M%S)"
dump_file="$DATA_DIR/dumps/saynata-$stamp.dump"
log "1/5 Dumping the VPS database to $dump_file"
# shellcheck disable=SC2016  # the variables expand inside the container
ssh "$VPS_HOST" "$remote_psql sh -c 'pg_dump -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" -Fc'" > "$dump_file.part"
[ -s "$dump_file.part" ] || { rm -f "$dump_file.part"; log "The dump is empty."; exit 1; }
mv "$dump_file.part" "$dump_file"
log "    size: $(du -h "$dump_file" | cut -f1)"

# --- 2. Media ------------------------------------------------------------------------------------------
log "2/5 Copying media from $VPS_HOST:$media_dir"
rsync -az "$VPS_HOST:$media_dir/" "$DATA_DIR/media/"
log "    files: $(find "$DATA_DIR/media" -type f | wc -l | tr -d ' ')"

# --- 3. Server settings --------------------------------------------------------------------------------
log "3/5 Copying the server .env to $DATA_DIR/vps.env"
scp -q "$VPS_HOST:$REMOTE_DIR/.env" "$DATA_DIR/vps.env"
chmod 600 "$DATA_DIR/vps.env"

# --- 4. Restore into the local Postgres ----------------------------------------------------------------
log "4/5 Restoring into the local Postgres (volume saynata-pgdata, port 5433)"
$compose_local exec -T postgres psql -q -U app -d english_translation \
  -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" >/dev/null
# --no-owner/--no-privileges: the local role is "app" too, but this keeps it working if that ever changes.
$compose_local exec -T postgres pg_restore -U app -d english_translation --no-owner --no-privileges --exit-on-error \
  < "$dump_file"

# --- 5. Compare row counts -----------------------------------------------------------------------------
log "5/5 Row counts (VPS | local)"
remote_counts="$(ssh "$VPS_HOST" "$remote_psql psql -U app -d english_translation -tA -c \"$count_sql\"")"
local_counts="$($compose_local exec -T postgres psql -U app -d english_translation -tA -c "$count_sql")"
# Tables can grow on the live server between the dump and the count, so a small "+" difference is normal.
join -t '|' -a 1 -a 2 -e '-' -o 0,1.2,2.2 <(echo "$remote_counts" | sort) <(echo "$local_counts" | sort) \
  | awk -F'|' '{ mark = ($2 == $3) ? "" : "  <- differs"; printf "    %-34s %10s %10s%s\n", $1, $2, $3, mark }'

log "Done. Next: start the backend (doc-11, section 20)."
