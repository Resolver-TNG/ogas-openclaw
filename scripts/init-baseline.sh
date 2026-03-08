#!/bin/bash
# init-baseline.sh — Initialize SHA-256 baseline for OGAS
# Usage: bash init-baseline.sh /path/to/workspace

set -euo pipefail

WORKSPACE="${1:?Usage: init-baseline.sh /path/to/workspace}"
SECURITY_DIR="$WORKSPACE/memory/security"
BASELINE="$SECURITY_DIR/baseline.json"

FILES=("SOUL.md" "AGENTS.md" "HEARTBEAT.md" "IDENTITY.md" "USER.md")

mkdir -p "$SECURITY_DIR"

echo "{" > "$BASELINE"
echo '  "generated": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",' >> "$BASELINE"
echo '  "workspace": "'$WORKSPACE'",' >> "$BASELINE"
echo '  "hashes": {' >> "$BASELINE"

FIRST=true
for f in "${FILES[@]}"; do
  FPATH="$WORKSPACE/$f"
  if [ -f "$FPATH" ]; then
    HASH=$(shasum -a 256 "$FPATH" | awk '{print $1}')
    if [ "$FIRST" = true ]; then
      FIRST=false
    else
      echo ',' >> "$BASELINE"
    fi
    printf '    "%s": "%s"' "$f" "$HASH" >> "$BASELINE"
  fi
done

echo '' >> "$BASELINE"
echo '  }' >> "$BASELINE"
echo '}' >> "$BASELINE"

echo "✅ Baseline created: $BASELINE"
echo "   Files tracked: ${#FILES[@]}"
cat "$BASELINE"
