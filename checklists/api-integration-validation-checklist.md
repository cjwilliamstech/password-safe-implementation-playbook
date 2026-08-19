# API Integration & Pilot Import Validation Checklist

For validating a Secrets Safe API integration (proof-of-concept or a script like
[`scripts/Import-SecretsSafeCredentials.ps1`](../scripts/Import-SecretsSafeCredentials.ps1))
before trusting it with a real import. Distinct from
[`discovery-and-import-checklist.md`](discovery-and-import-checklist.md), which covers
classifying and reviewing *what* gets imported — this one covers validating that the
*mechanism* itself is sound first.

## Before a pilot import

- [ ] Any API key used during interactive troubleshooting has been rotated
- [ ] Approved authentication rules (e.g. explicit source-IP restriction) restored
      after testing, not left relaxed
- [ ] API registration is active
- [ ] API registration is granted to **only** the required group(s) — not broadly
      assigned
- [ ] The `runas`/service account has the required Secrets Safe permissions, and is a
      member of a group the API registration is actually assigned to (see
      [`docs/05-api-authentication-and-session-mechanics.md`](../docs/05-api-authentication-and-session-mechanics.md)
      — this specific gap is the most common cause of a 401 that looks like a bad key)
- [ ] A test/pilot Safe or folder is selected — not a production target
- [ ] API sign-in returns HTTP 200
- [ ] Safes and folders can be successfully enumerated via the API
- [ ] Input CSV/manifest is stored securely and excluded from git (`.gitignore`
      covers `*.csv`, `*.log`, `*.transcript`, migration input/results folders)
- [ ] Dry-run (`-WhatIf` or equivalent) output has been reviewed and matches
      expectations before any real write calls run

## After a pilot import

- [ ] Resulting secret count matches the expected/successful row count from the
      import report
- [ ] Titles, usernames, descriptions, and folder paths spot-checked for correctness
- [ ] Owner assignments verified directly in the Secrets Safe console, not just
      inferred from the API response
- [ ] Intended users/groups **can** access the imported secrets
- [ ] Unintended users/groups **cannot** access the imported secrets
- [ ] Audit records are present for the import actions
- [ ] No passwords appear anywhere in logs, transcripts, or the results report
- [ ] API session was signed out (check for a `SignOut` failure warning even if the
      import itself succeeded — a failed sign-out can leave a session active on the
      appliance)
- [ ] Temporary/test secrets created during validation are removed per your normal
      change procedure
- [ ] The API registration used for the pilot is disabled or restricted once no
      longer needed, rather than left active indefinitely

## Scaling up

A reasonable progression, rather than jumping straight to a full production batch:

1. One non-production test credential, fully validated end-to-end.
2. A small pilot batch (e.g. 5 records) into a test/pilot Safe.
3. A controlled production import, batched (see the wave approach in
   [`runbooks/legacy-platform-migration-runbook.md`](../runbooks/legacy-platform-migration-runbook.md)),
   with the >50-item approval gate from
   [`discovery-and-import-checklist.md`](discovery-and-import-checklist.md) still
   applying regardless of how well the pilot went.
