# Import-SecretsSafeCredentials.ps1

Imports one Safe's worth of credential secrets into BeyondTrust Password Safe
**Secrets Safe**, filtered out of a multi-Safe shared-credentials export CSV, via the
REST API. Built to solve a specific gap: the Password Safe web UI's CSV importer only
supports **personal folders** — it cannot bulk-import into a shared/team Safe. This
script fills that gap.

## What it does

A typical legacy shared-credentials export contains rows for **many different target
Safes in a single CSV** (a `Password List` column identifies which Safe each row
belongs to). This script targets **one Safe per run**: you pass `-SafeName`, and it
filters the CSV down to only the rows belonging to that Safe before importing anything.
Run it once per Safe you're migrating.

High-level flow:

1. Prompt for an API key via a masked GUI dialog (never typed on the command line,
   never written to disk, console, or transcript).
2. Sign in to the Password Safe API.
3. Load the CSV, validate expected columns exist, and filter rows to the target Safe.
4. Resolve the target Safe — create it via `POST secrets-safe/safes` if it doesn't
   exist yet (unless `-AutoCreateSafe:$false`).
5. Import each matching row as a Secrets Safe secret.
6. Sign out and write a timestamped CSV report of what happened, row by row.

## Column mapping

| CSV column (default name) | Secrets Safe field | Notes |
|---|---|---|
| `System` | Title | |
| `Password List` | *(filter key only)* | Used to select rows for this run — not written to the secret itself |
| `Username` | Username | |
| `Password` | Password | Read from CSV, transmitted over HTTPS, never logged |
| `Comment` | Notes | Only set if the field has a value for that row |
| `Highlight`, `Last Change Time`, `Origin` | *(ignored)* | Not imported |

Column names are parameterized (`-TitleColumn`, `-SafeNameColumn`, `-UsernameColumn`,
`-PasswordColumn`, `-NotesColumn`) in case your export's headers differ from the
defaults above.

## Requirements

- PowerShell 5.1, Windows (uses `System.Windows.Forms` for the API key prompt)
- Network path from the host running the script to the appliance on TCP 443
- A Password Safe API key with permission to read/create Safes and create secrets
- Existing CSV export with at minimum: a title column, a Safe/list column, username,
  and password columns

## Parameters

| Parameter | Required | Default | Purpose |
|---|---|---|---|
| `-CsvPath` | Yes | — | Path to the full shared-credentials export CSV (multiple Safes allowed in one file) |
| `-SafeName` | Yes | — | Target Safe for this run; rows are filtered to matching `Password List` values (case-insensitive, trimmed) |
| `-AutoCreateSafe` | No | `$true` | Create the Safe via API if it doesn't already exist |
| `-SafeDescription` | No | `""` | Description set on the Safe if it's created |
| `-TeamGroupId` | No | `$null` | BeyondInsight GroupId. If set: grants this group Safe permissions on creation, and sets `OwnerType=Group`/`OwnerId` on every imported secret. If omitted: secrets are owned by the signed-in user, and a newly created Safe has no group permissions assigned yet (assign manually) |
| `-SafePermissionFlags` | No | `"Read, Create, Edit, Delete"` | Permission set granted to `-TeamGroupId` on Safe creation (regular-team tier — no Manage) |
| `-TitleColumn` | No | `"System"` | CSV column → Title |
| `-SafeNameColumn` | No | `"Password List"` | CSV column used as the filter key |
| `-UsernameColumn` | No | `"Username"` | CSV column → Username |
| `-PasswordColumn` | No | `"Password"` | CSV column → Password |
| `-NotesColumn` | No | `"Comment"` | CSV column → Notes (only if non-empty) |
| `-ApplianceBaseUrl` | No | `https://SERVERNAME/BeyondTrust/api/public/v3` | **Update to your appliance's real API base URL** |
| `-RunAsUser` | No | `yourdomain.com\username` | **Update to your real `runas` value** for the PS-Auth header |
| `-ServiceNowTask` | No | `""` | Optional ticket number, written into the report filename and summary for traceability |
| `-ReportPath` | No | `YOUR_FILE_PATH` | **Update to your real reporting output path** |
| `-WhatIf` | No | — | Dry run: validates the CSV, resolves/previews the Safe, shows what *would* happen. Makes no POST/PUT calls that create or modify anything. Still signs in/out. |

Three placeholders need updating for your environment before first use:
`-ApplianceBaseUrl` (if your appliance isn't `SERVERNAME`), `-RunAsUser`, and
`-ReportPath`'s default.

## Usage

Dry run first, always — validates the CSV and Safe resolution without writing
anything:

```powershell
.\Import-SecretsSafeCredentials.ps1 `
    -CsvPath "C:\Temp\shared-creds-export.csv" `
    -SafeName "SS-SecurityTools-SharedCreds" `
    -WhatIf
```

Real import, with a group assigned as owner/permission-holder on the Safe and secrets,
and a ServiceNow task reference for the audit trail:

```powershell
.\Import-SecretsSafeCredentials.ps1 `
    -CsvPath "C:\Temp\shared-creds-export.csv" `
    -SafeName "SS-Network-SharedCreds" `
    -TeamGroupId 57 `
    -ServiceNowTask "TASK12345"
```

Run once per target Safe — re-run with a different `-SafeName` for the next one.

## Output

A timestamped CSV report (`SecretsSafeImport_<SafeName>_<yyyyMMdd-HHmmss>.csv`) is
written to `-ReportPath` (or the current directory, with a warning, if that path is
unreachable). Each row records line number, title, status (`Success` / `Failed` /
`Skipped` / `WhatIf`), and a detail message — including the actual API error body on
failure, not just a generic HTTP status. A console summary prints total rows, rows
matched to this Safe vs. belonging to other Safes in the export, and a pass/fail/skip
count.

## Security notes

- **Never** reads the API key from a parameter, environment variable, or config file —
  it's entered interactively through a masked GUI prompt each run, held only in
  memory, and explicitly cleared (`Remove-Variable apiKey`) immediately after building
  the auth header.
- Plaintext passwords are read from the input CSV and transmitted over HTTPS to the
  appliance — they are **never** written to the console, a transcript, or the report
  file. Securing and deleting the source CSV after import is the operator's
  responsibility; this script does not do it for you.
- Rows missing a required field (title, username, or password) are skipped and logged
  as `Skipped` in the report rather than silently dropped or causing a partial/invalid
  secret to be created.
- A Safe created without `-TeamGroupId` is left with **no group permissions assigned**
  — the script warns about this explicitly rather than defaulting to broad access.

## Known limitations

- One Safe per run by design — this is deliberate (keeps each import reviewable and
  scoped), not a missing feature.
- Column mapping assumes a single flat CSV schema; if your export nests or splits
  data differently, adjust the `-*Column` parameters or pre-process the CSV first.
- `-WhatIf` on a Safe that doesn't exist yet can't preview individual secret creation
  (there's no Folder ID to target in dry-run) — it reports what *would* happen at the
  Safe level, then lists rows as `WhatIf` rather than simulating each API call.

## Related repo docs

- [`docs/04-architecture-decisions.md`](../docs/04-architecture-decisions.md) — Secrets
  Safe governance model and naming convention this script assumes
- [`checklists/discovery-and-import-checklist.md`](../checklists/discovery-and-import-checklist.md) —
  pre/post-import review steps, including the >50-item production approval gate
- [`runbooks/legacy-platform-migration-runbook.md`](../runbooks/legacy-platform-migration-runbook.md) —
  where this script fits into the broader migration sequence
