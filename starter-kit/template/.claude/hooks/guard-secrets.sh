#!/usr/bin/env bash
# PreToolUse hook for Bash. Stops shell commands that would print secrets into the chat
# (the Read deny rules in settings.json do not cover "cat .env" in a shell).
# Exit 2 blocks the tool call and sends stderr to Claude.

input=$(cat)
command=$(jq -r '.tool_input.command // empty' <<<"$input")

block() {
  echo "Blocked by .claude/hooks/guard-secrets.sh: $1. Use .env.example to see the key names." >&2
  exit 2
}

# Reading a .env file (but .env.example is fine).
if grep -Eq '(cat|less|more|head|tail|bat|grep|rg|sed|awk|source|\.)[[:space:]].*\.env([.][a-z]+)?([[:space:]]|$)' <<<"$command" \
   && ! grep -Eq '\.env\.example' <<<"$command"; then
  block "reading a .env file"
fi

# Dumping the whole environment.
if grep -Eq '(^|[;&|[:space:]])(env|printenv|export -p|set)([[:space:]]*($|[;&|]))' <<<"$command"; then
  block "printing all environment variables"
fi

# Private keys.
if grep -Eq '(cat|less|head|tail)[[:space:]].*\.(pem|key|p12|p8)([[:space:]]|$)' <<<"$command"; then
  block "reading a private key file"
fi

exit 0
