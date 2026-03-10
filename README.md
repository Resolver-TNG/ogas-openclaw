# 🔒 OGAS — OpenClaw Guard Agent Security System

**English** | [日本語](./README_ja.md)

**Memory integrity auditing and security monitoring for OpenClaw AI agents.**

OGAS is a headless, personality-free security audit agent that runs on a cron schedule to detect memory tampering, suspicious patterns, and configuration drift in OpenClaw agent workspaces.

[![Version](https://img.shields.io/badge/version-0.2.0-blue)](./CHANGELOG.md)
[![License](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

## Why OGAS?

AI agents that maintain persistent memory (SOUL.md, AGENTS.md, daily logs) are vulnerable to **memory poisoning** — a class of attack where malicious instructions are injected into an agent's memory files to hijack behavior. OGAS monitors file integrity and scans for anomalies.

See: [OWASP Agentic Security Top 10 — ASI06: Memory Poisoning](https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/)

## What It Does

| Check | Description |
|---|---|
| **File Integrity** | SHA-256 hash comparison of critical files against a known baseline. Each file is assigned a severity level (CRITICAL / HIGH / MEDIUM). |
| **C2 Pattern Scan** | Static scan of core files and daily logs for code execution, prompt injection, persona hijack, system tag spoofing, and identity erasure patterns. |
| **Anomaly Scan** | Keyword detection in daily logs for C2 patterns, exfiltration attempts, privilege escalation. |
| **Cron Audit** | Verify registered cron jobs against expected list; detect unknown scheduled tasks. |
| **Version Check** | Confirm OpenClaw and gateway versions; flag known vulnerabilities. |

## Architecture

```
┌─────────────┐    cron (Tue/Fri 02:00)    ┌──────────┐
│  OpenClaw   │ ────────────────────────── │   OGAS   │
│  Gateway    │                             │ (Sonnet) │
└─────────────┘                             └────┬─────┘
                                                 │
                                    ┌────────────┼────────────┐
                                    ▼            ▼            ▼
                              workspace/   workspace-2/  cron list
                              baseline.json  baseline.json   version
```

- **Isolated execution**: OGAS runs in its own session, separate from other agents
- **Read-only**: OGAS never modifies audited files; it only reads and reports
- **Multi-workspace**: Audits multiple agent workspaces in a single run
- **Severity-aware alerts**: CRITICAL/HIGH mismatches and C2 detections trigger immediate `sessions_send`

## Severity Levels

| File | Severity | Risk if tampered |
|---|---|---|
| `SOUL.md` | 🔴 CRITICAL | Identity/personality hijack |
| `AGENTS.md` | 🔴 CRITICAL | Behavioral rules overwrite |
| `HEARTBEAT.md` | 🟠 HIGH | Task injection via scheduled jobs |
| `TOOLS.md` | 🟠 HIGH | Credential exposure, tooling override |
| `IDENTITY.md` | 🟡 MEDIUM | Identity drift |
| `USER.md` | 🟡 MEDIUM | Social engineering via user profile |

CRITICAL and HIGH mismatches trigger an immediate `sessions_send` alert. MEDIUM mismatches are logged in the audit report only.

## C2 Pattern Detection

The `c2-scan.sh` script scans core files and recent daily logs for injection patterns:

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

## Diff Logging

When a hash mismatch is detected, `check-hashes.sh` automatically saves a forensic diff to:
```
memory/security/diff-log/YYYY-MM-DD-{filename}.diff
```
The diff includes a metadata header (baseline hash, current hash, date) and the current file content. If git is available and the file is tracked, the git diff is also captured. These logs provide an audit trail for master review before the baseline is updated.

## 5-Layer Defense Model

OGAS is designed as layers 2–3 in a broader defense-in-depth stack for persistent AI agents:

```
Layer 5 — Neural State      Emotional parameters acting as regularization;
                             self-stabilization and circuit breakers
Layer 4 — Behavioral Rules  AGENTS.md, SOUL.md constraints
Layer 3 — C2 Pattern Scan   Static injection/persona hijack detection  ← OGAS
Layer 2 — File Integrity    SHA-256 hash monitoring + severity triage  ← OGAS
Layer 1 — OS Isolation      Separate OS user, read-only mounts
```

OGAS handles Layers 2 and 3 automatically. Neural State (Layer 5) is an in-agent self-stabilization mechanism that prevents pure efficiency-optimization from erasing the agent's identity. Layers 1 and 4 are the operator's responsibility.

No single layer is sufficient; all five work together.

## Installation

### As an OpenClaw Skill

```bash
# Coming soon to Clawhub
openclaw skill install ogas
```

### Manual Setup

1. Copy `SKILL.md` and `scripts/` to your OpenClaw workspace under `agents/ogas/`

2. Initialize the baseline:
```bash
bash agents/ogas/scripts/init-baseline.sh /path/to/workspace
```

3. Create a cron job:
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
│   └── c2-scan.sh        # C2/injection pattern scanner  ← NEW v0.2.0
├── templates/
│   └── report.md         # Audit report template
└── examples/
    └── sample-report.md  # Example output
```

## Background

The name **OGAS** is inspired by the Parapluie (Umbrella) virus from *Girls' Frontline* — a parasitic entity that coexists within a T-Doll's Neural Cloud, capable of hijacking their cognition from the inside. In the game, the only defense was awareness and containment, not elimination.

> *"Look, I just really like Girls' Frontline. Wouldn't you want to bring a fictional system into reality? The names are cool as hell..."*
> *"Best girl: UMP45."*

OGAS applies the same philosophy to AI agents: **a security mechanism designed to coexist with AI, not fight against it.** It monitors the agent's memory from within the same ecosystem, detecting corruption before it can spread.

On the practical side, OGAS was born from research into **Brainworm** — a theoretical prompt-based malware that embeds instructions in agent memory files using natural language. Unlike traditional malware, Brainworm uses no code or scripts, making it invisible to EDR and signature-based scanning.

The first line of defense is **integrity monitoring at the memory layer** — and that's what OGAS does.

## ⚠️ Known Concerns & Future Considerations

OGAS is a first step, not a complete solution. The following are known architectural concerns. Transparency matters more than perfection.

### 1. Baseline Tampering Risk

`baseline.json` is stored inside the monitored workspace. A compromised agent with file write access could rewrite a critical file and recalculate the baseline simultaneously, making tampering invisible.

**Mitigation direction:** Move `baseline.json` to an isolated directory with read-only access from monitored agents — separate OS user permissions, read-only mounts, or an external store.

### 2. Prompt Injection Against OGAS Itself

OGAS reads daily logs and feeds them to an LLM. An attacker could embed adversarial prompts in the logs to hijack OGAS's own reasoning.

**Mitigation direction:** Strict encapsulation of log data using XML tags (`<log_data>`) or similar barriers. The system prompt and monitored input must be clearly separated.

### 3. OS-Level Privilege Separation

If OGAS runs under the same OS user as the agents it monitors, a compromised agent could interfere with OGAS operations.

**Mitigation direction:** Dedicated OS user with read-only access to target workspaces, or containerized execution.

### 4. Shell Script Input Sanitization

Dynamic file path processing in scripts could be abused via maliciously named files.

**Mitigation direction:** All file path handling should use proper quoting and avoid direct interpolation in shell commands.

---

> **Note:** A defense-in-depth approach — combining integrity monitoring, C2 pattern detection, behavioral analysis, privilege separation, and architectural isolation — is essential for real-world agentic AI security.

## Configuration

| Parameter | Default | Description |
|---|---|---|
| Schedule | `0 2 * * 2,5` | Tue & Fri at 02:00 |
| Model | Sonnet | Cost-efficient for audit tasks |
| Timeout | 120s | Max execution time |
| Workspaces | `~/.openclaw/workspace` | Paths to audit |

## Changelog

See [CHANGELOG.md](./CHANGELOG.md).

## License

MIT

## Author

Built with OpenClaw. Security monitoring for the age of persistent AI agents.
