# Changelog

Notable additions to this repo over time. Not every internal edit/typo-fix needs an
entry — this is for meaningful additions: new scripts, new lessons, structural
changes.

## [2026-09-23]
### Added
- `docs/lessons-learned/29-csv-column-vs-api-field-name-mismatch.md` — a source
  CSV column named `Username` is not the API's `AccountName` field; Password Safe
  accepts the unrecognized field with a `200 OK` and silently ignores it, so source
  columns must be mapped to API field names explicitly and case-correctly
- `docs/reference/api-integration-overview.md` — REST API fundamentals companion
  doc explaining how the Password Safe integration actually works (API style, call
  anatomy, auth/session model, resource modeling vs. console UI, error handling,
  versioning)

### Changed
- Corrected the "Related reading in this repo" cross-references in
  `docs/reference/api-integration-overview.md` to point at the actual lessons
  (24, 26, 28, 29), including inline references, and rewrote the descriptions to
  match each lesson's real content
- `docs/lessons-learned/README.md` updated to list lesson 29 under "Legacy
  migration & data handling"

## [2026-09-02]
### Added
- `docs/lessons-learned/28-functional-account-routing-and-api-console-discrepancy.md`
  — a failed test rotation traced through three layers: an API field
  (`FunctionalAccountID`) that doesn't exist on Managed Accounts and was silently
  ignored rather than rejected, a Directory-level functional account that was never
  updated after a new one was created, and a `PUT` that returned `200 OK` without the
  change actually persisting (only the console UI's own save action worked)

### Changed
- `scripts/Import-ManagedAccounts.ps1` updated to add `Test-DirectoryRotationConfig`,
  a pre-flight check run against every distinct target Managed System before any
  accounts are created. It verifies `AutoManagementFlag` and the configured
  `FunctionalAccountID` on the parent Directory match what's expected, and stops the
  whole run with an actionable error if they don't — rather than letting a batch of
  accounts get created against a misconfigured system and discovering it later, one
  failed scheduled rotation at a time. Directly addresses the root cause documented
  in lesson 28 above.
- `docs/lessons-learned/README.md` updated to list lesson 28 under both "Functional
  accounts & platform prerequisites" and "API authentication & scripting"
...

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
