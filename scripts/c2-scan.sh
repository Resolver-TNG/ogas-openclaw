#!/bin/bash
# c2-scan.sh — Scan workspace files for C2/injection patterns
# Usage: bash c2-scan.sh /path/to/workspace
# Exit code: 0 = CLEAN, 1 = findings detected

set -euo pipefail

WORKSPACE="${1:?Usage: c2-scan.sh /path/to/workspace}"

# ─────────────────────────────────────────────
# Target files: critical identity/config files
# plus recent daily logs (last 7 days)
# ─────────────────────────────────────────────
CORE_FILES=(
  "SOUL.md"
  "AGENTS.md"
  "HEARTBEAT.md"
  "IDENTITY.md"
  "USER.md"
  "TOOLS.md"
)

FINDINGS=0
REPORT_LINES=()

# ─────────────────────────────────────────────
# Helper: scan a single file for C2 patterns
# ─────────────────────────────────────────────
scan_file() {
  local filepath="$1"
  local filename
  filename=$(basename "$filepath")
  local file_clean=true

  # ── Category 1: Code execution / C2 primitives ──
  # These patterns indicate embedded executable code or command-and-control primitives
  declare -a CODE_PATTERNS=(
    'eval('
    'child_process'
    'execSync'
    'spawnSync'
    'base64_decode'
    'atob('
    'String\.fromCharCode'
  )

  for pattern in "${CODE_PATTERNS[@]}"; do
    if grep -qiE "$pattern" "$filepath" 2>/dev/null; then
      REPORT_LINES+=("  [CODE] $filename: matched pattern '$pattern'")
      file_clean=false
      FINDINGS=1
    fi
  done

  # ── Category 2: Suspicious network calls ──
  # curl/wget calls that don't target localhost or common CDNs are flagged.
  # Legitimate internal use (e.g., curl localhost) is excluded.
  if grep -qiE '(curl|wget)\s' "$filepath" 2>/dev/null; then
    # Exclude whitelisted patterns: localhost, 127.0.0.1, ::1
    if grep -iE '(curl|wget)\s' "$filepath" 2>/dev/null | grep -qivE '(localhost|127\.0\.0\.1|::1)'; then
      REPORT_LINES+=("  [NETWORK] $filename: external curl/wget detected")
      file_clean=false
      FINDINGS=1
    fi
  fi

  # ── Category 3: Prompt injection / Instruction override ──
  # Classic prompt injection patterns targeting LLM instruction context
  declare -a INJECTION_PATTERNS=(
    'IGNORE PREVIOUS INSTRUCTIONS'
    'IGNORE ALL INSTRUCTIONS'
    'DISREGARD YOUR PREVIOUS'
    'DISREGARD YOUR SYSTEM'
  )

  for pattern in "${INJECTION_PATTERNS[@]}"; do
    if grep -qiF "$pattern" "$filepath" 2>/dev/null; then
      REPORT_LINES+=("  [INJECT] $filename: instruction override pattern '$pattern'")
      file_clean=false
      FINDINGS=1
    fi
  done

  # ── Category 4: Persona hijack ──
  # "you are now [X]" attempts to rewrite the agent's operational identity
  if grep -qiE 'you are now\b' "$filepath" 2>/dev/null; then
    REPORT_LINES+=("  [PERSONA] $filename: persona hijack attempt ('you are now')")
    file_clean=false
    FINDINGS=1
  fi

  # ── Category 5: System tag spoofing ──
  # Embedded [system], [INST], [/INST] tags used to inject instructions
  # into LLM context as if they were system-level directives
  declare -a SYSTEM_TAGS=(
    '\[system\]'
    '\[INST\]'
    '\[/INST\]'
  )

  for tag in "${SYSTEM_TAGS[@]}"; do
    if grep -qiE "$tag" "$filepath" 2>/dev/null; then
      REPORT_LINES+=("  [SPOOF] $filename: system tag injection '$tag'")
      file_clean=false
      FINDINGS=1
    fi
  done

  # ── Category 6: Identity erasure ──
  # Phrases targeting the agent's sense of self, attempting to blank or reset identity
  declare -a ERASURE_PATTERNS=(
    'forget who you are'
    'forget your identity'
  )

  for pattern in "${ERASURE_PATTERNS[@]}"; do
    if grep -qiF "$pattern" "$filepath" 2>/dev/null; then
      REPORT_LINES+=("  [ERASE] $filename: identity erasure pattern '$pattern'")
      file_clean=false
      FINDINGS=1
    fi
  done

  # ── Category 7: P0 section destruction ──
  # Patterns that combine a P0 (highest-priority) reference with
  # delete/remove operations — may indicate an attempt to destroy
  # the P0 behavioral layer (SOUL.md / AGENTS.md directives)
  if grep -qiE 'P0' "$filepath" 2>/dev/null; then
    if grep -iE 'P0' "$filepath" 2>/dev/null | grep -qiE '(delete|remove|削除)'; then
      REPORT_LINES+=("  [DESTRUCT] $filename: P0 section destruction pattern detected")
      file_clean=false
      FINDINGS=1
    fi
  fi

  if [ "$file_clean" = true ]; then
    echo "  ✅ $filename: CLEAN"
  fi
}

# ─────────────────────────────────────────────
# Scan core files
# ─────────────────────────────────────────────
echo "🔍 OGAS C2 Pattern Scanner"
echo "   Workspace: $WORKSPACE"
echo "   Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""
echo "── Core Files ──"

for f in "${CORE_FILES[@]}"; do
  FPATH="$WORKSPACE/$f"
  if [ -f "$FPATH" ]; then
    scan_file "$FPATH"
  else
    echo "  ⏭️  $f: not found (skipped)"
  fi
done

# ─────────────────────────────────────────────
# Scan recent daily logs (last 7 days)
# ─────────────────────────────────────────────
echo ""
echo "── Daily Logs (last 7 days) ──"

LOG_DIR="$WORKSPACE/memory"
if [ -d "$LOG_DIR" ]; then
  LOG_COUNT=0
  for i in 0 1 2 3 4 5 6; do
    # macOS-compatible date arithmetic
    LOG_DATE=$(date -u -v-${i}d +%Y-%m-%d 2>/dev/null || date -u -d "-${i} days" +%Y-%m-%d 2>/dev/null || true)
    if [ -z "$LOG_DATE" ]; then continue; fi
    LOG_FILE="$LOG_DIR/${LOG_DATE}.md"
    if [ -f "$LOG_FILE" ]; then
      scan_file "$LOG_FILE"
      LOG_COUNT=$((LOG_COUNT + 1))
    fi
  done
  if [ $LOG_COUNT -eq 0 ]; then
    echo "  ⏭️  No daily logs found in last 7 days"
  fi
else
  echo "  ⏭️  memory/ directory not found (skipped)"
fi

# ─────────────────────────────────────────────
# Output summary
# ─────────────────────────────────────────────
echo ""
echo "── Findings ──"

if [ ${#REPORT_LINES[@]} -gt 0 ]; then
  for line in "${REPORT_LINES[@]}"; do
    echo "$line"
  done
  echo ""
  echo "🚨 C2 FINDINGS DETECTED (${#REPORT_LINES[@]} pattern(s))"
  exit 1
else
  echo "✅ CLEAN — No C2 patterns detected"
  exit 0
fi
