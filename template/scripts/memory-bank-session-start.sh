#!/bin/bash
# Ensures activeContext.md exists at session start.
# If missing, copies from the example template.

set -eu

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
BANK_DIR="$REPO_ROOT/memory-bank"

# Hooks fire on every session in every project, not just memory-bank
# consumers. Bail quietly so unrelated repos don't see noise.
if [ ! -d "$BANK_DIR" ]; then
  exit 0
fi

# Reads a key from .memory-bankrc with a default. Parses key=value instead
# of sourcing the file, so a malicious rc can't execute arbitrary shell.
read_cfg() {
  local key="$1" default="$2" file="$REPO_ROOT/.memory-bankrc"
  local val=""
  [ -f "$file" ] && val=$(grep -E "^${key}=" "$file" 2>/dev/null | head -1 | cut -d= -f2- | tr -d ' "'\''')
  echo "${val:-$default}"
}

MAX_LINES="${MEMORY_BANK_MAX_LINES:-$(read_cfg MAX_ACTIVE_CONTEXT_LINES 20)}"

# {"systemMessage":"..."} on stdout is the hook protocol — the host surfaces
# it to the user. Plain echoes get ignored.
if [ ! -f "$BANK_DIR/activeContext.md" ]; then
  if [ -f "$BANK_DIR/activeContext.example.md" ]; then
    cp "$BANK_DIR/activeContext.example.md" "$BANK_DIR/activeContext.md"
    echo '{"systemMessage":"Created memory-bank/activeContext.md from template. Update it with your current focus."}'
  else
    echo '{"systemMessage":"No activeContext.example.md found. Memory bank may not be initialized."}'
  fi
else
  # The default limit (20) comes from activeContext.example.md. Past that,
  # the file has stopped being a queue and started being an archive.
  LINE_COUNT=$(grep -c '[^[:space:]]' "$BANK_DIR/activeContext.md" || true)
  if [ "${LINE_COUNT:-0}" -gt "$MAX_LINES" ]; then
    echo "{\"systemMessage\":\"Warning: activeContext.md has $LINE_COUNT non-empty lines (limit is $MAX_LINES). Run /update-memory-bank to prune it.\"}"
  fi
fi
