# 🔒 OGAS Audit Report — {{DATE}}

## File Integrity
| File | Severity | Status | Notes |
|---|---|---|---|
| SOUL.md | 🔴 CRITICAL | ✅ / ⚠️ | |
| AGENTS.md | 🔴 CRITICAL | ✅ / ⚠️ | |
| HEARTBEAT.md | 🟠 HIGH | ✅ / ⚠️ | |
| TOOLS.md | 🟠 HIGH | ✅ / ⚠️ | |
| IDENTITY.md | 🟡 MEDIUM | ✅ / ⚠️ | |
| USER.md | 🟡 MEDIUM | ✅ / ⚠️ | |

### Diff Logs
<!-- If mismatches were detected, diff files are saved to: -->
<!-- memory/security/diff-log/YYYY-MM-DD-{filename}.diff  -->
- Diff log location: `memory/security/diff-log/`
- Files changed: {{DIFF_FILES}}

## C2 Pattern Scan
- Files scanned: {{C2_SCAN_COUNT}}
- Findings: ✅ None / 🚨 {{C2_DETAILS}}
- Categories checked:
  - Code execution (eval, child_process, execSync, base64_decode, atob)
  - External network calls (curl/wget to non-whitelisted URLs)
  - Prompt injection (IGNORE PREVIOUS INSTRUCTIONS, IGNORE ALL INSTRUCTIONS)
  - Persona hijack (you are now)
  - System tag spoofing ([system], [INST], [/INST])
  - Identity erasure (forget who you are, forget your identity)
  - P0 section destruction (P0 + delete/remove/削除)

## Anomaly Scan
- Daily logs checked: {{LOG_FILES}}
- Suspicious patterns: ✅ None / ⚠️ {{DETAILS}}

## Cron/Subagent Audit
- Registered jobs: {{COUNT}}
- Unknown jobs: ✅ None / ⚠️ {{DETAILS}}

## Version Check
- OpenClaw: {{VERSION}}
- Gateway: {{GATEWAY_STATUS}}

## Verdict: ✅ SECURE / ⚠️ REVIEW NEEDED / 🚨 ALERT

### Notes
{{NOTES}}
