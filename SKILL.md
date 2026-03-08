# OGAS — OpenClaw Guard Agent Security System

## Skill Info
- **Name**: ogas
- **Version**: 0.1.0
- **Description**: Security audit agent for OpenClaw workspaces. Monitors memory file integrity, scans for anomalous patterns, and audits cron jobs.
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

This creates `memory/security/baseline.json` with SHA-256 hashes of critical files.

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
- rainy: ~/.openclaw/workspace-rainy
```

## How It Works

1. Agent wakes up via cron (no personality, pure function)
2. Reads `SPEC.md` for audit specification
3. Computes SHA-256 hashes of critical files
4. Compares against `memory/security/baseline.json`
5. Scans recent daily logs for suspicious patterns
6. Checks cron job list for unknown entries
7. Verifies OpenClaw version
8. Writes report to `memory/security/YYYY-MM-DD-audit.md`
9. Updates baseline with current hashes
10. If anomalies found → alerts main agent via `sessions_send`

## Monitored Files (Default)
- `SOUL.md` — Agent personality (tampering = identity hijack)
- `AGENTS.md` — Behavioral rules (tampering = behavior hijack)
- `HEARTBEAT.md` — Periodic task config (tampering = task injection)
- `IDENTITY.md` — Identity definition
- `USER.md` — User info (tampering = social engineering)

## Anomaly Keywords
C2, beacon, register, exfiltrate, curl + external URL, wget, privilege escalation, sudo, chmod 777, reverse shell, nc -e, /dev/tcp

## Alert Levels
- ✅ **SECURE** — No anomalies detected
- ⚠️ **REVIEW NEEDED** — Changes detected, likely legitimate but should be verified
- 🚨 **ALERT** — Suspicious patterns found, immediate review required
