# Runbook: Bulk-Import Managed Accounts via API (with Password Seeding and Per-Account Rotation Scheduling)

## When to Use This

Use this runbook when onboarding a batch of existing service accounts into
Password Safe as Managed Accounts, where:

- There is no native UI bulk-import path for Managed Accounts (unlike
  Secrets Safe, which supports CSV import for personal folders only).
- You want to seed each account's current password at creation, to avoid a
  forced first rotation on a legacy account whose real password isn't yet
  known to Password Safe.
- Accounts have individual, non-uniform rotation schedules (common when
  rotation timing is constrained by system/application impact windows and
  account owner availability, rather than a single company-wide schedule).

## Prerequisites

- [ ] Confirm the target Managed System ID for the directory these
      accounts belong to (`GET ManagedSystems`, filter to
      `EntityTypeID` = Directory).
- [ ] Confirm the Functional Account ID that will perform rotation, and
      that its `PlatformID` matches the target Managed System's
      `PlatformID` (`GET FunctionalAccounts`).
- [ ] **Confirm Auto-Management is enabled at the Managed System level**
      (`GET ManagedSystems/{id}`, check `AutoManagementFlag`). Account-level
      `AutoManagementFlag: true` is rejected with a 400 error if the parent
      system doesn't also have it enabled — this is a one-time,
      environment-wide setting, not something to toggle per import run.
- [ ] Prepare the main import CSV (account metadata — no passwords) with
      columns: `AccountName, SAMAccountName, UserPrincipalName, DomainName,
      ManagedSystemID, SeedPassword, ChangeFrequencyDays, ChangeTime,
      NextChangeDate, Notes`.
      - `ChangeTime` must be in **UTC**. If your rotation windows were
        communicated in local time, convert before populating this column.
      - `NextChangeDate` accepts common date formats (the script
        normalizes `M/D/YYYY`, `MM/DD/YYYY`, `YYYY-MM-DD`, etc.) so values
        copied directly from a legacy platform's export don't need manual
        reformatting.
- [ ] If seeding passwords, prepare a **same-day** secure export
      (`AccountName, Password`) from your encrypted credential store —
      generate it immediately before running the script, not in advance.

## Steps

1. **Validate the account status list first.** Cross-reference your
   intended import list against a fresh AD status check (Active / Disabled
   / Not Found) before finalizing the import CSV. Exclude disabled and
   unresolvable accounts; do not assume a legacy export's account list
   still reflects current AD state.

2. **Run a dry run (`-WhatIf`).** This validates CSV parsing, confirms the
   password export lookup resolves for every `SeedPassword=true` row, and
   reports exactly what each account's schedule and system assignment
   would be — with zero calls that create or modify anything.

3. **Review the dry-run report in full**, not just the summary counts.
   Confirm `ChangeFrequencyDays`/`ChangeTime`/`NextChangeDate` per account
   match what was actually agreed with each account owner — a copy/paste
   or unit mismatch (daily vs. annual, local time vs. UTC) is far cheaper
   to catch here than after live rotation begins.

4. **Run for real**, without `-WhatIf`. Recommend leaving password-export
   purge disabled for the first live batch, so the export is available to
   inspect if anything unexpected happens; enable purge-after-run once the
   pipeline is proven for your environment.

5. **Check `PasswordValidated` for every seeded account** in the resulting
   report — this is the result of a live `Credentials/Test` call, and is
   the only thing that actually confirms the seeded password matches the
   live system. `Status: Created` alone only confirms the account object
   was created, not that its password is correct.

6. **Address any `Failed` rows** using the detailed error message printed
   to console and recorded in the report (the script surfaces the actual
   API response body, not just an HTTP status code).

## Rollback

- If an account was created with an incorrect schedule or a failed seed
  validation, it can be corrected via `PUT ManagedAccounts/{id}` rather
  than deleted and recreated.
- If an account should not have been created at all,
  `DELETE ManagedAccounts/{id}` removes it; confirm no dependent Smart
  Rule or linked-system reference exists first.
- The password export file used for seeding should never be the only
  record of an account's password — if `PasswordValidated` shows a
  mismatch, treat it as a signal to investigate drift between the export
  source and the live system, not to silently retry.

## Related

- See lessons-learned entries on: password seeding vs. forced rotation,
  API `runas` domain format, `-WhatIf` propagation to reporting steps,
  surfacing API error bodies, and the system-level Auto-Management
  prerequisite.
