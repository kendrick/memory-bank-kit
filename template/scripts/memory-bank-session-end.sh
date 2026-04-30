#!/bin/bash
# Reminds the developer to update the memory bank if significant work was done.

set -eu

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

if [ ! -d "$REPO_ROOT/memory-bank" ]; then
  exit 0
fi

CHANGED_FILES=$(git -C "$REPO_ROOT" diff --name-only HEAD 2>/dev/null | wc -l | tr -d ' ' || echo 0)

if [ "${CHANGED_FILES:-0}" -gt 5 ]; then
  echo "{\"systemMessage\":\"You changed $CHANGED_FILES files this session. Consider running /update-memory-bank or @memory-bank-synchronizer to keep the memory bank current.\"}"
fi
