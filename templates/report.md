# 🔒 OGAS Audit Report — {{DATE}}

## File Integrity
| File | Status | Notes |
|---|---|---|
| SOUL.md | ✅ / ⚠️ | |
| AGENTS.md | ✅ / ⚠️ | |
| HEARTBEAT.md | ✅ / ⚠️ | |
| IDENTITY.md | ✅ / ⚠️ | |
| USER.md | ✅ / ⚠️ | |

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
