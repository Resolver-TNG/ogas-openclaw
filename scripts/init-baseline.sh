#!/bin/bash
# init-baseline.sh — Initialize SHA-256 baseline for OGAS
# Usage: bash init-baseline.sh /path/to/workspace
#
# v0.2.0: Each file entry now includes "hash", "size", and "severity" fields.
# Severity levels:
#   CRITICAL — tampering = identity/permission hijack (SOUL.md, AGENTS.md)
#   HIGH     — tampering = task injection or credential exposure (HEARTBEAT.md, TOOLS.md)
#   MEDIUM   — tampering = social engineering or identity drift (IDENTITY.md, USER.md)

set -euo pipefail

WORKSPACE="${1:?Usage: init-baseline.sh /path/to/workspace}"
SECURITY_DIR="$WORKSPACE/memory/security"
BASELINE="$SECURITY_DIR/baseline.json"

mkdir -p "$SECURITY_DIR"

# ─────────────────────────────────────────────
# File list with severity assignments
# Format: "filename:SEVERITY"
# ─────────────────────────────────────────────
declare -a FILE_SEVERITY=(
  "SOUL.md:CRITICAL"
  "AGENTS.md:CRITICAL"
  "HEARTBEAT.md:HIGH"
  "TOOLS.md:HIGH"
  "IDENTITY.md:MEDIUM"
  "USER.md:MEDIUM"
)

echo "{" > "$BASELINE"
echo '  "generated": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",' >> "$BASELINE"
echo '  "version": "0.2.0",' >> "$BASELINE"
echo '  "workspace": "'$WORKSPACE'",' >> "$BASELINE"
echo '  "files": {' >> "$BASELINE"

FIRST=true
TRACKED=0

for entry in "${FILE_SEVERITY[@]}"; do
  # Split "filename:SEVERITY" on the colon
  FNAME="${entry%%:*}"
  SEVERITY="${entry##*:}"
  FPATH="$WORKSPACE/$FNAME"

  if [ -f "$FPATH" ]; then
    HASH=$(shasum -a 256 "$FPATH" | awk '{print $1}')
    SIZE=$(wc -c < "$FPATH" | tr -d ' ')

    if [ "$FIRST" = true ]; then
      FIRST=false
    else
      echo ',' >> "$BASELINE"
    fi

    # Write a structured object for each file
    printf '    "%s": { "hash": "%s", "size": %s, "severity": "%s" }' \
      "$FNAME" "$HASH" "$SIZE" "$SEVERITY" >> "$BASELINE"

    TRACKED=$((TRACKED + 1))
  fi
done

echo '' >> "$BASELINE"
echo '  }' >> "$BASELINE"
echo '}' >> "$BASELINE"

echo "✅ Baseline created: $BASELINE"
echo "   Files tracked: $TRACKED"
echo ""
cat "$BASELINE"
