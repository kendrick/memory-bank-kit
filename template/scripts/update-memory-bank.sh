#!/bin/bash
# Manual memory bank sync trigger.
# Works from any terminal — not tied to a specific AI tool.
# Prints a summary of memory bank staleness for the developer to act on.

set -eu

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
BANK_DIR="$REPO_ROOT/memory-bank"

echo "=== Memory Bank Status ==="
echo ""

if [ ! -d "$BANK_DIR" ]; then
  echo "No memory-bank/ directory found at $REPO_ROOT."
  echo "Run the memory-bank-kit installer to scaffold one."
  exit 1
fi

# activeContext.md status
if [ -f "$BANK_DIR/activeContext.md" ]; then
  LINES=$(grep -c '[^[:space:]]' "$BANK_DIR/activeContext.md" || echo 0)
  echo "activeContext.md: $LINES non-empty lines (limit: 20)"
else
  echo "activeContext.md: MISSING — run: cp memory-bank/activeContext.example.md memory-bank/activeContext.md"
fi

# Last modified times
echo ""
echo "Last modified:"
for f in "$BANK_DIR"/*.md; do
  [ -f "$f" ] || continue
  BASENAME=$(basename "$f")
  if [[ "$OSTYPE" == "darwin"* ]]; then
    MOD=$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f")
  else
    MOD=$(stat -c '%y' "$f" | cut -d. -f1)
  fi
  echo "  $BASENAME: $MOD"
done

# Recent change context
echo ""
echo "Recent changes (last 5 commits):"
git -C "$REPO_ROOT" diff --stat HEAD~5 2>/dev/null || echo "  (not enough git history)"
