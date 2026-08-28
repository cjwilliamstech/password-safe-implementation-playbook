# Import-ManagedAccounts.ps1

Bulk-creates Password Safe **Managed Accounts** via the REST API — optionally seeding
each account's current password, and configuring an individual rotation schedule per
account, all in one create call per row.

Complements [`Import-SecretsSafeCredentials.ps1`](Import-SecretsSafeCredentials.ps1)
(which handles the static/shared-secret side of a migration): this script is for the
**rotatable** side — accounts you want Password Safe to actively own and rotate going
forward, not static values.

## Why this exists

There's no native UI bulk-import for Managed Accounts (unlike Secrets Safe, which has
a personal-folder CSV import). The Smart Rule + Directory Query discovery pattern
(covered in [`docs/04-architecture-decisions.md`](../docs/04-architecture-decisions.md))
creates the Managed Account shell automatically, but has no way to know the account's
*current* password — that gap normally has to be closed manually per account via
Edit Managed Account → Set Password. This script is the alternative path: when you
already know the target `ManagedSystemID` for a batch of accounts, it seeds the
current password and full rotation schedule at creation time, skipping that manual
step entirely — useful when you also need per-account rotation windows rather than one
global schedule (a common constraint when rotation timing depends on individual
system/application impact tolerance).

## What it does, per CSV row

1. Creates the Managed Account (`POST ManagedSystems/{systemID}/ManagedAccounts`)
   with the full rotation schedule embedded in the same call.
2. If `SeedPassword=true` for that row, includes the current password (sourced from a
   **separate**, same-day secure export — never from the main input CSV).
3. Immediately calls `POST ManagedAccounts/{id}/Credentials/Test` to validate the
   seeded password against the live system, without changing it — converting a
   potentially stale export into an immediate, visible pass/fail result instead of a
   future support ticket.
4. Records the outcome (`Created` / `Failed` / `PasswordValidated: Yes|NO - MISMATCH`)
   in a row-by-row report.

## Two-file input design (this is deliberate, not incidental)

- **`-CsvPath`** — account metadata only. **No password column.** Columns:
  `AccountName, SAMAccountName, UserPrincipalName, DomainName, ManagedSystemID,
  SeedPassword, ChangeFrequencyDays, ChangeTime, NextChangeDate, Notes`
- **`-SecureExportPath`** — a separate file, `AccountName,Password`, generated fresh
  from your encrypted credential store **on the same day** you run the script — not
  in advance. Loaded into memory once, converted to `SecureString` immediately, and
  optionally purged (best-effort overwrite + delete) after the run with
  `-PurgeExportAfterRun`.

Keeping these as two separate files means the primary migration manifest (which you
might reasonably want to keep around for reference, review, or re-runs) never contains
a plaintext password column.

## Why per-account rotation fields, not script-level defaults

`ChangeFrequencyDays`, `ChangeTime`, and `NextChangeDate` are **CSV columns**, not
top-level script parameters, because rotation windows are typically dictated by
individual system/application impact tolerance and account owner availability — there
usually isn't one after-hours window that fits an entire batch. Rows that leave these
blank fall back to `-DefaultChangeFrequencyDays` / `-DefaultChangeTime`, but that's
meant to be the exception, not the norm.

**`ChangeTime` must be in UTC.** If rotation windows were agreed upon in local time,
convert before populating the CSV.

## Prerequisites

Also see [`checklists/api-integration-validation-checklist.md`](../checklists/api-integration-validation-checklist.md)
and the runbook below for the full pre-flight sequence. The one prerequisite that will
otherwise cause every seeded account to fail with a 400 error:

- **Auto-Management must already be enabled at the parent Managed System level**
  (`GET ManagedSystems/{id}`, check `AutoManagementFlag`). Setting the flag on an
  individual account has no effect if the parent system doesn't also have it enabled
  — this is a one-time, environment-wide setting, not something to toggle per import
  run. See [lesson 27](../docs/lessons-learned/27-system-level-auto-management-and-linked-account-anchor.md).

## Usage

Always dry-run first:

```powershell
.\Import-ManagedAccounts.ps1 -CsvPath "C:\Temp\Wave1-Accounts.csv" `
    -ApiBaseUrl "https://<appliance>/BeyondTrust/api/public/v3" `
    -FunctionalAccountID <id> `
    -SecureExportPath "C:\Secure\wave1-passwords.csv" `
    -WhatIf
```

Real run, with export purge enabled and a ticket reference for the audit trail:

```powershell
.\Import-ManagedAccounts.ps1 -CsvPath "C:\Temp\Wave1-Accounts.csv" `
    -ApiBaseUrl "https://<appliance>/BeyondTrust/api/public/v3" `
    -FunctionalAccountID <id> `
    -SecureExportPath "C:\Secure\wave1-passwords.csv" `
    -PurgeExportAfterRun -ServiceNowTask "TASK0012345"
```

Recommendation for the first live batch: leave `-PurgeExportAfterRun` off so the
export is available to inspect if anything unexpected happens, and enable it once the
pipeline is proven for your environment.

## Security notes

- The API key is read from the `PWSAFE_API_KEY` machine-scoped environment variable
  (same pattern as `Import-SecretsSafeCredentials.ps1`), or prompted via a masked
  WinForms dialog if not present — never a script parameter or literal.
- The main input CSV never contains a password column, and the script never writes a
  password to disk, the report, or the console/transcript.
- `-PurgeExportAfterRun` is a **best-effort** cleanup (overwrite then delete) — on
  SSDs or journaling filesystems this doesn't guarantee the original bytes are
  unrecoverable at the hardware level. The real control is your encrypted folder's
  access policy and how briefly the plaintext export exists outside it; treat the
  purge flag as a courtesy, not a substitute for that.
- `-WhatIf` still loads the secure export into memory (so password lookups can be
  validated) but never calls `Credentials/Test`, since no account was actually
  created to test against.

## Related repo docs

- [`docs/lessons-learned/23-bulk-account-creation-password-seeding.md`](../docs/lessons-learned/23-bulk-account-creation-password-seeding.md)
- [`docs/lessons-learned/24-api-runas-domain-format-401.md`](../docs/lessons-learned/24-api-runas-domain-format-401.md)
- [`docs/lessons-learned/25-whatif-propagation-suppresses-reporting.md`](../docs/lessons-learned/25-whatif-propagation-suppresses-reporting.md)
- [`docs/lessons-learned/26-surface-api-error-bodies-not-status-codes.md`](../docs/lessons-learned/26-surface-api-error-bodies-not-status-codes.md)
- [`docs/lessons-learned/27-system-level-auto-management-and-linked-account-anchor.md`](../docs/lessons-learned/27-system-level-auto-management-and-linked-account-anchor.md)
- [`runbooks/bulk-import-managed-accounts-via-api.md`](../runbooks/bulk-import-managed-accounts-via-api.md) — full step-by-step procedure
- [`checklists/api-integration-validation-checklist.md`](../checklists/api-integration-validation-checklist.md)
