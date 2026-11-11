#!/usr/bin/env bash
# Fails unless the pack's manifest has "status": "alpha". Packs come in as alpha; only the registry's own
# automation (task 64) or a maintainer makes one verified.
#
#   scripts/check-alpha.sh <pack folder>
set -euo pipefail

manifest="${1:?usage: check-alpha.sh <pack folder>}/manifest.json"
if [[ -L "$manifest" || ! -f "$manifest" ]]; then
  echo "::error file=$manifest,title=manifest.json::must be a plain file"
  exit 1
fi
status="$(jq -r '.status // empty' "$manifest" 2>/dev/null || true)"
if [[ "$status" != "alpha" ]]; then
  echo "::error file=$manifest,title=status::a new pack or revision must have \"status\": \"alpha\" (found \"${status:-none}\"); it becomes verified after players confirm it works"
  exit 1
fi
echo "$manifest: status alpha"
