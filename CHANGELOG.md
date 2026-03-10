# Changelog

## [0.2.0] — 2026-03-10

### Added
- **C2 Pattern Scanner** (`scripts/c2-scan.sh`): Static analysis of core files and daily logs for code execution primitives, external network calls, prompt injection, persona hijack, system tag spoofing, identity erasure, and P0 destruction patterns.
- **File Severity Levels**: Each monitored file is assigned CRITICAL / HIGH / MEDIUM severity. Severity is stored in `baseline.json` and reflected in reports and alerts.
- **Diff Logging**: When a hash mismatch is detected, `check-hashes.sh` saves a forensic diff to `memory/security/diff-log/YYYY-MM-DD-{filename}.diff`.
- **Severity-Aware Alerts**: CRITICAL and HIGH mismatches trigger immediate `sessions_send` alerts. MEDIUM mismatches are logged in reports only — no notification noise.
- **Exit code semantics**: `check-hashes.sh` now returns 2 for CRITICAL mismatches, 1 for HIGH/MEDIUM, 0 for all-clear.

### Changed
- `init-baseline.sh`: Now generates structured `baseline.json` with `hash`, `size`, and `severity` fields per file (backward compatible — `check-hashes.sh` falls back for v0.1.0 format).
- `prompt.md`: Restructured into 5 clear audit steps with severity-aware alerting rules.
- `templates/report.md`: Added severity column, C2 scan section, and diff log references.
- `examples/sample-report.md`: Updated to demonstrate v0.2.0 features.
- `README.md` / `README_ja.md`: Added C2 detection, severity levels, diff logging documentation.
- `SKILL.md`: Bumped to v0.2.0, documented new features and file structure.

## [0.1.0] — 2026-03-05

### Added
- Initial release
- SHA-256 hash baseline comparison for 5 core files
- Anomaly keyword scanning in daily logs
- Cron job audit
- OpenClaw version check
- Multi-workspace support
