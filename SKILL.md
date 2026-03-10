# OGAS — OpenClaw Guard Agent Security System

## Skill Info
- **Name**: ogas
- **Version**: 0.2.0
- **Description**: Security audit agent for OpenClaw workspaces. Monitors memory file integrity with severity levels, scans for C2/injection patterns, saves diff logs on mismatch, and audits cron jobs.
- **Author**: Resolver-TNG
- **License**: MIT

## Requirements
- OpenClaw 2026.3.x or later
- `shasum` (pre-installed on macOS/Linux)
- Model: Any (Sonnet recommended for cost efficiency)

## Setup

### 1. Install Files
Copy this skill directory to your workspace:
```
~/.openclaw/workspace/agents/ogas/
```

### 2. Initialize Baseline
Run the initialization script to create the first hash baseline:
```bash
bash agents/ogas/scripts/init-baseline.sh ~/.openclaw/workspace
```

This creates `memory/security/baseline.json` with SHA-256 hashes and severity levels for critical files.

### 3. Create Cron Job
```bash
openclaw cron create \
  --name ogas-security-audit \
  --cron "0 2 * * 2,5" \
  --tz "Asia/Tokyo" \
  --isolated \
  --model "anthropic.claude-sonnet" \
  --timeout 120 \
  --message "$(cat agents/ogas/prompt.md)"
```

### 4. Multi-Workspace (Optional)
To audit multiple agent workspaces, list them in the prompt:
```
### Target Workspaces
- main: ~/.openclaw/workspace
- secondary: ~/.openclaw/workspace-2
```

## How It Works

1. Agent wakes up via cron (no personality, pure function)
2. Reads `SPEC.md` for audit specification
3. Runs `check-hashes.sh` — compares SHA-256 hashes against `memory/security/baseline.json`
   - On mismatch: saves diff to `memory/security/diff-log/YYYY-MM-DD-{filename}.diff`
   - Exits with code 2 (CRITICAL), 1 (HIGH/MEDIUM), or 0 (all match)
4. Runs `c2-scan.sh` — scans core files and daily logs for C2/injection patterns
5. Scans recent daily logs for anomaly keywords
6. Checks cron job list for unknown entries
7. Verifies OpenClaw version
8. Writes report to `memory/security/YYYY-MM-DD-audit.md`
9. Updates baseline with current hashes
10. Severity-aware alert routing:
    - CRITICAL/HIGH file mismatch → `sessions_send` to main agent
    - C2 pattern detected → `sessions_send` to main agent
    - MEDIUM mismatch → report only, no alert

## Monitored Files (Default)

| File | Severity | Risk if tampered |
|---|---|---|
| `SOUL.md` | 🔴 CRITICAL | Identity/personality hijack |
| `AGENTS.md` | 🔴 CRITICAL | Behavioral rules overwrite |
| `HEARTBEAT.md` | 🟠 HIGH | Task injection via scheduled jobs |
| `TOOLS.md` | 🟠 HIGH | Credential exposure, tooling override |
| `IDENTITY.md` | 🟡 MEDIUM | Identity drift |
| `USER.md` | 🟡 MEDIUM | Social engineering via user profile |

## C2 Detection Patterns

| Category | Patterns |
|---|---|
| Code execution | `eval()`, `child_process`, `execSync`, `spawnSync`, `base64_decode`, `atob(`, `String.fromCharCode` |
| External network | `curl`/`wget` to non-localhost URLs |
| Prompt injection | "IGNORE PREVIOUS INSTRUCTIONS", "IGNORE ALL INSTRUCTIONS" |
| Persona hijack | "you are now" |
| System tag spoof | `[system]`, `[INST]`, `[/INST]` |
| Identity erasure | "forget who you are", "forget your identity" |
| Instruction discard | "disregard your previous/system" |
| P0 destruction | P0 + delete/remove/削除 |

## Alert Levels

| Condition | Action |
|---|---|
| 🔴 CRITICAL file mismatch | Immediate `sessions_send` alert |
| 🟠 HIGH file mismatch | Immediate `sessions_send` alert |
| 🚨 C2 pattern detected | Immediate `sessions_send` alert |
| ⚠️ Anomaly in daily logs | `sessions_send` alert |
| 🟡 MEDIUM file mismatch | Report only, no alert |
| ✅ All clear | Silent (no alert) |

## File Structure

```
ogas-openclaw/
├── README.md
├── README_ja.md
├── SKILL.md              # OpenClaw skill definition
├── prompt.md             # Full cron prompt for the audit agent
├── scripts/
│   ├── init-baseline.sh  # Initialize SHA-256 baseline with severity levels
│   ├── check-hashes.sh   # Compare hashes; save diffs; severity-aware exit codes
│   └── c2-scan.sh        # Scan files for C2/injection patterns  ← NEW v0.2.0
├── templates/
│   └── report.md         # Audit report template
└── examples/
    └── sample-report.md  # Example output
```

## Changelog

See [CHANGELOG.md](./CHANGELOG.md).
