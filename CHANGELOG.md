# Changelog

Notable additions to this repo over time. Not every internal edit/typo-fix needs an
entry — this is for meaningful additions: new scripts, new lessons, structural
changes.

## [2026-08-27]
### Added
- `scripts/Import-ManagedAccounts.ps1` — bulk Managed Account creation via the
  Password Safe REST API, with per-account rotation scheduling and optional
  current-password seeding, plus [`scripts/Import-ManagedAccounts.md`](scripts/Import-ManagedAccounts.md)
- `runbooks/bulk-import-managed-accounts-via-api.md`
- 5 new lessons learned (API `runas` domain format, `-WhatIf` propagation to
  reporting, surfacing API error bodies, system-level Auto-Management prerequisite,
  password seeding vs. forced rotation)

### Changed
- Restructured `docs/01-lessons-learned.md` (one growing file) into
  `docs/lessons-learned/` (one file per lesson, with a grouped index) — the single
  file was becoming hard to scan as the lesson count grew past 20

## [Earlier]
- Initial repo structure: README, lessons learned, architecture decisions, key
  concepts, glossary, checklists (pre-deployment, discovery/import, access
  configuration), templates (firewall rules, Smart Rule examples, functional account
  setup, AD group mapping, ADFS/SAML troubleshooting), runbooks (legacy platform
  migration, break-glass procedure), and `scripts/Import-SecretsSafeCredentials.ps1`
  for Secrets Safe bulk import
- Added `docs/05-api-authentication-and-session-mechanics.md` and
  `checklists/api-integration-validation-checklist.md` from a Secrets Safe API
  proof-of-concept
