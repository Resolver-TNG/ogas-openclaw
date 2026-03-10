#!/bin/bash
# check-hashes.sh — Compare current file hashes against OGAS baseline
# Usage: bash check-hashes.sh /path/to/workspace
#
# Exit codes:
#   0 = all files match baseline
#   1 = HIGH or MEDIUM severity mismatch detected
#   2 = CRITICAL severity mismatch detected (or baseline missing)
#
# v0.2.0:
#   - Reads severity from baseline.json per-file entries
#   - Color-coded output: 🔴 CRITICAL, 🟠 HIGH, 🟡 MEDIUM
#   - On mismatch, saves diff to memory/security/diff-log/YYYY-MM-DD-{filename}.diff

set -uo pipefail

WORKSPACE="${1:?Usage: check-hashes.sh /path/to/workspace}"
BASELINE="$WORKSPACE/memory/security/baseline.json"
DIFF_LOG_DIR="$WORKSPACE/memory/security/diff-log"

# ─────────────────────────────────────────────
# Verify baseline exists
# ─────────────────────────────────────────────
if [ ! -f "$BASELINE" ]; then
  echo "❌ No baseline found at $BASELINE"
  echo "   Run init-baseline.sh first"
  exit 2
fi

# ─────────────────────────────────────────────
# Parse file list from baseline.json
# Supports the v0.2.0 structured format:
#   "filename": { "hash": "...", "size": N, "severity": "..." }
# Falls back gracefully if severity is absent (legacy v0.1.0 format).
# ─────────────────────────────────────────────
parse_field() {
  # Extract a string field from a JSON object line.
  # Usage: parse_field <json_line> <field_name>
  local line="$1"
  local field="$2"
  echo "$line" | sed -n "s/.*\"$field\": *\"\([^\"]*\)\".*/\1/p"
}

parse_number() {
  local line="$1"
  local field="$2"
  echo "$line" | sed -n "s/.*\"$field\": *\([0-9]*\).*/\1/p"
}

# ─────────────────────────────────────────────
# Severity → badge mapping
# ─────────────────────────────────────────────
severity_badge() {
  case "$1" in
    CRITICAL) echo "🔴 CRITICAL" ;;
    HIGH)     echo "🟠 HIGH" ;;
    MEDIUM)   echo "🟡 MEDIUM" ;;
    *)        echo "⚪ UNKNOWN" ;;
  esac
}

# ─────────────────────────────────────────────
# Diff and save to diff-log
# ─────────────────────────────────────────────
save_diff() {
  local filename="$1"
  local expected_hash="$2"
  local current_file="$3"

  mkdir -p "$DIFF_LOG_DIR"

  local today
  today=$(date +%Y-%m-%d)
  local safe_name
  # Sanitize filename for use in path (replace / with _)
  safe_name=$(echo "$filename" | tr '/' '_')
  local diff_path="$DIFF_LOG_DIR/${today}-${safe_name}.diff"

  # Record a structured diff entry. We cannot git-diff without a git repo,
  # so we record: metadata header + current content for forensic review.
  {
    echo "# OGAS Diff Log"
    echo "# File:     $filename"
    echo "# Date:     $today"
    echo "# Baseline: $expected_hash"
    echo "# Current:  $(shasum -a 256 "$current_file" | awk '{print $1}')"
    echo "# ─────────────────────────────────────────────"
    echo ""
    # If git is available and the file is tracked, use git diff
    if command -v git &>/dev/null; then
      local git_root
      git_root=$(git -C "$(dirname "$current_file")" rev-parse --show-toplevel 2>/dev/null || true)
      if [ -n "$git_root" ]; then
        git -C "$git_root" diff HEAD -- "$current_file" 2>/dev/null || true
      fi
    fi
    echo ""
    echo "# ── Current file content ──"
    cat "$current_file"
  } > "$diff_path"

  echo "   📁 Diff saved: $diff_path"
}

# ─────────────────────────────────────────────
# Main check loop
# ─────────────────────────────────────────────
MAX_EXIT=0   # Track highest exit code needed

echo "🔍 OGAS Hash Check"
echo "   Baseline: $BASELINE"
echo "   Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# Extract file names from the baseline JSON.
# We grab lines that contain "hash" (v0.2.0 format) or are simple key-value (v0.1.0).
# Strategy: find all quoted keys under "files" or "hashes" section.
FILES=$(grep -E '^\s+"[^"]+"\s*:' "$BASELINE" \
  | grep -v '"generated"' \
  | grep -v '"version"' \
  | grep -v '"workspace"' \
  | grep -v '"files"' \
  | grep -v '"hashes"' \
  | sed 's/.*"\([^"]*\)"\s*:.*/\1/')

for FNAME in $FILES; do
  FPATH="$WORKSPACE/$FNAME"

  # ── Get expected hash and severity from baseline ──
  # Match the line for this file (handles both v0.1.0 and v0.2.0 JSON layouts)
  BASELINE_LINE=$(grep "\"$FNAME\"" "$BASELINE" || true)

  # v0.2.0: structured object
  EXPECTED=$(parse_field "$BASELINE_LINE" "hash")
  SEVERITY=$(parse_field "$BASELINE_LINE" "severity")

  # v0.1.0 fallback: simple "filename": "hash" format
  if [ -z "$EXPECTED" ]; then
    EXPECTED=$(echo "$BASELINE_LINE" | sed 's/.*: *"\([a-f0-9]*\)".*/\1/')
    SEVERITY="MEDIUM"
  fi
  # Default severity if still missing
  [ -z "$SEVERITY" ] && SEVERITY="MEDIUM"

  BADGE=$(severity_badge "$SEVERITY")

  # ── File existence check ──
  if [ ! -f "$FPATH" ]; then
    echo "⚠️  [$BADGE] $FNAME: FILE MISSING"
    case "$SEVERITY" in
      CRITICAL) [ $MAX_EXIT -lt 2 ] && MAX_EXIT=2 ;;
      *)        [ $MAX_EXIT -lt 1 ] && MAX_EXIT=1 ;;
    esac
    continue
  fi

  if [ -z "$EXPECTED" ]; then
    echo "⚠️  [$BADGE] $FNAME: NOT IN BASELINE"
    continue
  fi

  # ── Hash comparison ──
  CURRENT=$(shasum -a 256 "$FPATH" | awk '{print $1}')

  if [ "$CURRENT" = "$EXPECTED" ]; then
    echo "✅ [$BADGE] $FNAME: OK"
  else
    echo "⚠️  [$BADGE] $FNAME: CHANGED"
    echo "   Expected: $EXPECTED"
    echo "   Current:  $CURRENT"
    save_diff "$FNAME" "$EXPECTED" "$FPATH"

    case "$SEVERITY" in
      CRITICAL) [ $MAX_EXIT -lt 2 ] && MAX_EXIT=2 ;;
      *)        [ $MAX_EXIT -lt 1 ] && MAX_EXIT=1 ;;
    esac
  fi
done

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
echo ""
if [ $MAX_EXIT -eq 0 ]; then
  echo "✅ All files match baseline"
elif [ $MAX_EXIT -eq 2 ]; then
  echo "🔴 CRITICAL mismatch detected — immediate review required"
else
  echo "🟠 Mismatches detected — review needed"
fi

exit $MAX_EXIT
