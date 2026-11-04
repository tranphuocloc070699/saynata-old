#!/usr/bin/env bash
# TASK-118: refresh word_form on the VPS in one go. Run on the Mac from anywhere:
#   exports/word-forms/import_word_forms.sh
# 1. export known words from the VPS  2. build word_forms.tsv (lemminflect, no LLM)  3. load it (one transaction)
# Safe to run again: the table is replaced as a whole, and a failed load changes nothing.
set -euo pipefail

SSH_HOST="${SSH_HOST:-vps_sieutoc}"
PSQL="docker exec -i backend-postgres-1 psql -U app -d english_translation -v ON_ERROR_STOP=1"

cd "$(dirname "$0")/../.."   # repo root
TSV=exports/word-forms/word_forms.tsv

echo "1/3 Exporting known words from $SSH_HOST..."
ssh "$SSH_HOST" "$PSQL -At -c \"select lower(lemma) from dictionary_word union select lower(form) from dictionary_form union select lower(word) from word_lookup order by 1\"" > existing_words.txt
count=$(wc -l < existing_words.txt | tr -d ' ')
if [ "$count" -lt 10000 ]; then
  echo "Only $count words exported, something is wrong. Stopped before the import." >&2
  exit 1
fi
echo "    $count words."

echo "2/3 Building $TSV..."
(cd pipeline && uv run python ../exports/word-forms/build_word_forms.py > /dev/null)
rows=$(( $(wc -l < "$TSV") - 1 ))
echo "    $rows form -> lemma rows (details: exports/word-forms/report.md)."

echo "3/3 Loading into word_form on $SSH_HOST..."
copy_sql="\\copy word_form (form, lemma, form_type, kind) FROM STDIN WITH (FORMAT csv, DELIMITER E'\\t', HEADER true)"
ssh "$SSH_HOST" "$PSQL -1 -c 'TRUNCATE word_form' -c $(printf %q "$copy_sql")" < "$TSV"
ssh "$SSH_HOST" "$PSQL -c 'select kind, count(*) from word_form group by kind'"

echo "Done. Test: contaminated, ran, gave up. Then commit existing_words.txt and exports/word-forms/."