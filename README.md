# 🔒 OGAS — OpenClaw Guard Agent Security System

**English** | [日本語](./README_ja.md)

**Memory integrity auditing and security monitoring for OpenClaw AI agents.**

OGAS is a headless, personality-free security audit agent that runs on a cron schedule to detect memory tampering, suspicious patterns, and configuration drift in OpenClaw agent workspaces.

## Why OGAS?

AI agents that maintain persistent memory (SOUL.md, AGENTS.md, daily logs) are vulnerable to **memory poisoning** — a class of attack where malicious instructions are injected into an agent's memory files to hijack behavior. OGAS monitors file integrity and scans for anomalies.

See: [OWASP Agentic Security Top 10 — ASI06: Memory Poisoning](https://owasp.org/www-project-agentic-ai-threats/)

## What It Does

| Check | Description |
|---|---|
| **File Integrity** | SHA-256 hash comparison of critical files (SOUL.md, AGENTS.md, etc.) against a known baseline |
| **Anomaly Scan** | Keyword detection in daily logs for C2 patterns, exfiltration attempts, privilege escalation |
| **Cron Audit** | Verify registered cron jobs against expected list; detect unknown scheduled tasks |
| **Version Check** | Confirm OpenClaw and gateway versions; flag known vulnerabilities |

## Architecture

```
┌─────────────┐    cron (Tue/Fri 02:00)    ┌──────────┐
│  OpenClaw   │ ────────────────────────── │   OGAS   │
│  Gateway    │                             │ (Sonnet) │
└─────────────┘                             └────┬─────┘
                                                 │
                                    ┌────────────┼────────────┐
                                    ▼            ▼            ▼
                              workspace/   workspace-rainy/  cron list
                              baseline.json  baseline.json   version
```

- **Isolated execution**: OGAS runs in its own session, separate from other agents
- **Read-only**: OGAS never modifies audited files; it only reads and reports
- **Multi-workspace**: Audits multiple agent workspaces in a single run
- **Alert routing**: Anomalies are reported via `sessions_send` to the main agent

## Installation

### As an OpenClaw Skill

```bash
# Coming soon to Clawhub
openclaw skill install ogas
```

### Manual Setup

1. Copy `SKILL.md` and `scripts/` to your OpenClaw workspace under `agents/ogas/`

2. Create a cron job:

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

3. Initialize the baseline:

```bash
# Generate initial hash baseline for your workspace
bash agents/ogas/scripts/init-baseline.sh /path/to/workspace
```

## File Structure

```
ogas-openclaw/
├── README.md
├── SKILL.md              # OpenClaw skill definition
├── prompt.md             # Full cron prompt for the audit agent
├── scripts/
│   ├── init-baseline.sh  # Initialize SHA-256 baseline
│   └── check-hashes.sh   # Compare current hashes against baseline
├── templates/
│   └── report.md         # Audit report template
└── examples/
    └── sample-report.md  # Example output
```

## Report Format

```markdown
🔒 OGAS Audit Report — 2026-03-07

## File Integrity
- SOUL.md: ✅ No changes
- AGENTS.md: ⚠️ Change detected (diff: +3 lines, section: Memory)

## Anomaly Scan
- ✅ No suspicious patterns

## Cron/Subagent Audit
- Registered jobs: 6
- ✅ All known

## Version
- OpenClaw: 2026.3.2 ✅

## Verdict: ⚠️ REVIEW NEEDED
```

## Background

The name **OGAS** is inspired by the Parapluie (Umbrella) virus from *Girls' Frontline* — a parasitic entity that coexists within a T-Doll's Neural Cloud, capable of hijacking their cognition from the inside. In the game, the only defense was awareness and containment, not elimination.

> *"Look, I just really like Girls' Frontline. Wouldn't you want to bring a fictional system into reality? The names are cool as hell..."*
> *"Best girl: UMP45."*

OGAS applies the same philosophy to AI agents: **a security mechanism designed to coexist with AI, not fight against it.** It monitors the agent's memory from within the same ecosystem, detecting corruption before it can spread.

On the practical side, OGAS was born from research into **Brainworm** — a theoretical prompt-based malware that embeds instructions in agent memory files using natural language. Unlike traditional malware, Brainworm uses no code or scripts, making it invisible to EDR and signature-based scanning.

The first line of defense is **integrity monitoring at the memory layer** — and that's what OGAS does.

## Configuration

| Parameter | Default | Description |
|---|---|---|
| Schedule | `0 2 * * 2,5` | Tue & Fri at 02:00 |
| Model | Sonnet | Cost-efficient for audit tasks |
| Timeout | 120s | Max execution time |
| Workspaces | `~/.openclaw/workspace` | Comma-separated paths to audit |

## License

MIT

## Author

Built with OpenClaw. Security monitoring for the age of persistent AI agents.
