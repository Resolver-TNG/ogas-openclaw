#!/bin/bash
# check-hashes.sh — Compare current file hashes against baseline
# Usage: bash check-hashes.sh /path/to/workspace
# Exit code: 0 = all match, 1 = mismatch detected

set -euo pipefail

WORKSPACE="${1:?Usage: check-hashes.sh /path/to/workspace}"
BASELINE="$WORKSPACE/memory/security/baseline.json"

if [ ! -f "$BASELINE" ]; then
  echo "❌ No baseline found at $BASELINE"
  echo "   Run init-baseline.sh first"
  exit 2
fi

FILES=("SOUL.md" "AGENTS.md" "HEARTBEAT.md" "IDENTITY.md" "USER.md")
MISMATCH=0

for f in "${FILES[@]}"; do
  FPATH="$WORKSPACE/$f"
  if [ ! -f "$FPATH" ]; then
    echo "⚠️  $f: FILE MISSING"
    MISMATCH=1
    continue
  fi

  CURRENT=$(shasum -a 256 "$FPATH" | awk '{print $1}')
  # Extract expected hash from baseline JSON
  EXPECTED=$(grep "\"$f\"" "$BASELINE" | sed 's/.*: *"\([a-f0-9]*\)".*/\1/')

  if [ -z "$EXPECTED" ]; then
    echo "⚠️  $f: NOT IN BASELINE"
    continue
  fi

  if [ "$CURRENT" = "$EXPECTED" ]; then
    echo "✅ $f: OK"
  else
    echo "⚠️  $f: CHANGED"
    echo "   Expected: $EXPECTED"
    echo "   Current:  $CURRENT"
    MISMATCH=1
  fi
done

if [ $MISMATCH -eq 0 ]; then
  echo ""
  echo "✅ All files match baseline"
else
  echo ""
  echo "⚠️  Mismatches detected — review needed"
fi

exit $MISMATCH
