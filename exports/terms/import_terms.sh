#!/usr/bin/env bash
# TASK-119.2: replace term and term_alias on the VPS with exports/terms/*.tsv, in one transaction. Run on the Mac:
#   exports/terms/import_terms.sh
# Build the files first: cd pipeline && uv run python -m pipeline.terms
# Safe to run again: both tables are replaced as a whole, and a failed load changes nothing.
set -euo pipefail

SSH_HOST="${SSH_HOST:-vps_sieutoc}"
CONTAINER="${CONTAINER:-backend-postgres-1}"
PSQL="docker exec -i $CONTAINER psql -U app -d english_translation -v ON_ERROR_STOP=1"

cd "$(dirname "$0")"
for file in terms.tsv term_aliases.tsv; do
  if [ ! -s "$file" ]; then
    echo "$file is missing. Build it first: cd pipeline && uv run python -m pipeline.terms" >&2
    exit 1
  fi
done

echo "Copying the files to $SSH_HOST..."
scp -q terms.tsv term_aliases.tsv "$SSH_HOST:/tmp/"
# psql's \copy reads files on the client side, and the client runs inside the container, so the files go in there.
ssh "$SSH_HOST" "docker cp /tmp/terms.tsv $CONTAINER:/tmp/terms.tsv && docker cp /tmp/term_aliases.tsv $CONTAINER:/tmp/term_aliases.tsv && rm /tmp/terms.tsv /tmp/term_aliases.tsv"

echo "Loading..."
ssh "$SSH_HOST" "$PSQL -1 -f -" <<'SQL'
TRUNCATE term CASCADE;
\copy term (wikidata_id, name, field, simple_definition, official_url, wikipedia_url, popularity) FROM '/tmp/terms.tsv' WITH (FORMAT csv, DELIMITER E'\t', HEADER true)
CREATE TEMP TABLE alias_in (alias_key VARCHAR(100), wikidata_id VARCHAR(16), source VARCHAR(16));
\copy alias_in FROM '/tmp/term_aliases.tsv' WITH (FORMAT csv, DELIMITER E'\t', HEADER true)
INSERT INTO term_alias (alias_key, term_id, source)
SELECT a.alias_key, t.id, a.source FROM alias_in a JOIN term t ON t.wikidata_id = a.wikidata_id
ON CONFLICT DO NOTHING;
SELECT (SELECT count(*) FROM term) AS terms, (SELECT count(*) FROM term_alias) AS aliases;
SQL

ssh "$SSH_HOST" "docker exec $CONTAINER rm -f /tmp/terms.tsv /tmp/term_aliases.tsv"
echo "Done. Test: curl -s https://api.saynata.com/api/words/nuxtjs | jq .terms"
