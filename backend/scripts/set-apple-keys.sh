#!/usr/bin/env bash
# Puts the Sign in with Apple revoke keys (TASK-112.3) into backend/.env, then offers to redeploy.
# Run on the server:  /var/www/saynata/backend/scripts/set-apple-keys.sh <AuthKey_XXXXXXXXXX.p8> <TEAM_ID> [KEY_ID]
#   - the .p8 file: Apple Developer, Keys, a "Sign in with Apple" key (doc-11 section 13, "Revoke on delete")
#   - TEAM_ID: 10 characters, Apple Developer, Membership details
#   - KEY_ID: 10 characters; read from the file name AuthKey_<KEY_ID>.p8 when left out
# Safe to run again: it replaces APPLE_TEAM_ID, APPLE_KEY_ID and APPLE_PRIVATE_KEY, and keeps an
# APPLE_TOKEN_ENCRYPTION_KEY that is already set (a new one could not read the stored tokens).
# backend/.env is copied to backend/.env.bak-<time> first. Nothing is changed when an input looks wrong.
set -euo pipefail

cd "$(dirname "$0")/.."    # the backend/ folder, where .env lives

p8="${1:-}"
team_id="${2:-}"
key_id="${3:-}"

fail() { echo "Stopped, nothing changed: $*" >&2; exit 1; }

echo "1/4 Checking the inputs"
[ -n "$p8" ] && [ -n "$team_id" ] || fail "usage: $0 <AuthKey_XXXXXXXXXX.p8> <TEAM_ID> [KEY_ID]"
[ -f "$p8" ] || fail "$p8 does not exist."
[ -f .env ] || fail "backend/.env is missing (doc-11)."
grep -q -- "-----BEGIN PRIVATE KEY-----" "$p8" || fail "$p8 is not a .p8 key (no BEGIN PRIVATE KEY line)."
# The whole key must parse as EC P-256 (what Apple gives); a broken key would stop the backend from starting.
openssl pkey -in "$p8" -noout 2>/dev/null || fail "$p8 cannot be read as a private key (cut off or broken?)."
openssl pkey -in "$p8" -noout -text 2>/dev/null | grep -q -E "prime256v1|P-256" \
  || fail "$p8 is not an EC P-256 key; Sign in with Apple keys are."
if [ -z "$key_id" ]; then
  key_id="$(basename "$p8" | sed -n 's/^AuthKey_\([A-Z0-9]*\)\.p8$/\1/p')"
  [ -n "$key_id" ] || fail "cannot read the key ID from the file name; give it as the third argument."
fi
[[ "$team_id" =~ ^[A-Z0-9]{10}$ ]] || fail "TEAM_ID '$team_id' should be 10 capital letters or digits."
[[ "$key_id" =~ ^[A-Z0-9]{10}$ ]] || fail "KEY_ID '$key_id' should be 10 capital letters or digits."

# One line, each newline written as \n: the backend turns it back (RemoteAppleTokenApi.parsePrivateKey).
private_key="$(awk 'NF {printf "%s\\n", $0}' "$p8")"

existing_enc="$(sed -n 's/^APPLE_TOKEN_ENCRYPTION_KEY[[:space:]]*[=:][[:space:]]*//p' .env | tail -1)"
# Compose drops surrounding quotes, so KEY="" is an empty key: strip them before the check.
existing_enc="${existing_enc#\"}"; existing_enc="${existing_enc%\"}"
existing_enc="${existing_enc#\'}"; existing_enc="${existing_enc%\'}"
if [ -n "$existing_enc" ]; then
  enc="$existing_enc"
  echo "    APPLE_TOKEN_ENCRYPTION_KEY is already set; it is kept."
else
  enc="$(openssl rand -base64 32)"
  echo "    A new APPLE_TOKEN_ENCRYPTION_KEY was made."
fi

echo "2/4 Backing up backend/.env"
backup=".env.bak-$(date +%Y%m%d-%H%M%S)"
cp .env "$backup"
chmod 600 "$backup"
echo "    $backup"

echo "3/4 Writing the four keys"
tmp="$(mktemp)"
grep -v -E '^(APPLE_TEAM_ID|APPLE_KEY_ID|APPLE_PRIVATE_KEY|APPLE_TOKEN_ENCRYPTION_KEY)=|^# Sign in with Apple revoke keys ' .env > "$tmp" || true
{
  echo ""
  echo "# Sign in with Apple revoke keys (TASK-112.3), written by scripts/set-apple-keys.sh on $(date +%F)"
  echo "APPLE_TEAM_ID=$team_id"
  echo "APPLE_KEY_ID=$key_id"
  echo "APPLE_PRIVATE_KEY=$private_key"
  echo "APPLE_TOKEN_ENCRYPTION_KEY=$enc"
} >> "$tmp"
mv "$tmp" .env
chmod 600 .env
echo "    APPLE_TEAM_ID=$team_id, APPLE_KEY_ID=$key_id, APPLE_PRIVATE_KEY (hidden), APPLE_TOKEN_ENCRYPTION_KEY (hidden)"

echo "4/4 Redeploy"
read -r -p "    Restart the backend now with scripts/deploy.sh? [y/N] " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
  ./scripts/deploy.sh
  echo "Done. The start log should no longer say \"Apple token keys are not set\":"
  echo "    docker compose -f docker-compose.prod.yml logs backend | grep -i 'apple token'"
else
  echo "Not restarted. Run ./scripts/deploy.sh when ready."
fi
echo "You can now delete the .p8 file from the server: $p8"
