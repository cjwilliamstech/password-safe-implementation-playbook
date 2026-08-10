# Legacy PAM Platform → Password Safe Migration Runbook

Generic runbook for migrating off an end-of-life or deprecated PAM tool onto Password
Safe. Based on a real migration off BeyondTrust's legacy on-prem product (Privileged
Identity / "RED-IM"), but the pattern generalizes to other source platforms.

## Phase 0 — Inventory & classification

- [ ] Export the full credential inventory from the legacy platform
- [ ] For each item, classify: **rotatable** (candidate for Managed Account) vs.
      **static/shared** (candidate for Secrets Safe)
- [ ] Note any unusual file encodings in legacy exports before writing parsing scripts
      (e.g. UTF-16 LE vs. UTF-8 — a common surprise with older Windows-native tools;
      `Import-Csv`/`Get-Content` in PowerShell need the correct `-Encoding` parameter or
      values will silently corrupt)
- [ ] Identify owners for each credential/group of credentials — legacy platforms often
      have stale or missing ownership metadata; this is a good forcing function to
      clean it up rather than migrate ambiguity forward

## Phase 1 — Pilot migration (Secrets Safe path)

For static/shared credentials with no rotation story:

1. Create a pilot Safe (e.g. `Legacy-Shared-Secrets-Pilot`) separate from the eventual
   production destination.
2. Manually migrate a small sample (5–10 items) to validate the process end-to-end:
   folder structure, naming convention, owner assignment, and access permissions.
3. Confirm the pilot items are visible and correctly permissioned before scaling up.
4. Design the target production Safe/subfolder structure to mirror how teams actually
   think about ownership (not necessarily how the legacy tool organized things).

## Phase 2 — Bulk migration

1. Build/adapt a bulk import script against the Secrets Safe REST API (see
   [`templates/secrets-safe-bulk-import.ps1`](../templates/secrets-safe-bulk-import.ps1))
   — the UI CSV importer will not work for team Safes.
2. Request the necessary firewall path (automation host → appliance, TCP 443) early —
   this is a common bottleneck since it's easy to miss in initial firewall planning.
3. Run the bulk import into the **pilot** Safe first, even for what will become the
   production batch — validate before promoting.
4. **Approval gate:** get explicit sign-off before importing more than ~50 items into
   a production-scoped Safe.

## Phase 3 — Rotatable credential migration (Managed Account path)

For credentials that should become actively rotated Managed Accounts instead:

1. Confirm target systems are already onboarded as Managed Systems (or onboard them
   first via discovery).
2. Confirm a functional account exists with appropriate rights for the platform.
3. Onboard as Managed Accounts through the normal discovery/import flow — **do not**
   route these through the Secrets Safe bulk import path, they need the rotation
   lifecycle instead.

## Phase 4 — Validation

- [ ] Sample of migrated Secrets Safe items spot-checked for correct value, owner, and
      access permissions
- [ ] Sample of migrated Managed Accounts confirmed to rotate successfully
- [ ] Access from the legacy platform's equivalent user groups mapped and tested
      against the new Password Safe roles
- [ ] Legacy platform access left in place (read-only or otherwise limited) until the
      new platform is fully validated in production use — don't decommission
      prematurely

## Migration priority tiers

A useful way to triage a large legacy inventory rather than migrating everything at
once:

```
PRIORITY 1 — Active + present in legacy tool + delegation group already exists
  Cleanest migration path. New role-based-access group name can usually be
  auto-derived from the legacy delegation group name.
  Move account to the target Managed Accounts OU, build/confirm Smart Rule
  coverage, assign the mapped access group, validate rotation.

PRIORITY 2 — Active + present in legacy tool + direct (non-group) access only
  Assign the relevant admin users to the new access group first,
  since there's no existing group to map from directly.
  Then migrate the account.

PRIORITY 3 — Active + NOT present in the legacy tool at all
  These need ownership verification before migrating — don't assume they belong
  in scope just because they were discovered. Confirm with the account owner
  whether Password Safe management is actually needed, or whether the account
  should be marked explicitly out of scope.
```

## Wave approach

Migrate in waves rather than all at once — this contains blast radius if a wave
surfaces an unexpected issue (permission gap, encoding problem, naming collision):

```
Wave 1: Test/pilot accounts only
Wave 2+: Priority 1 accounts, batched by entity/business unit
         (batch size of 20-30 accounts per wave is a reasonable starting point —
         small enough to review carefully, large enough to make real progress)
Later waves: Database accounts (once DB functional accounts are provisioned),
             then Priority 3 accounts after ownership review
```

## Illustrative scale (example from a real migration — numbers will vary by org)

To give a sense of what a legacy-platform migration inventory can actually look like
once you run the numbers — useful for scoping your own project's timeline:

| Category | Example count |
|---|---|
| Total service accounts in AD inventory | ~800 |
| Active accounts | ~390 |
| Disabled accounts (candidates for cleanup, not migration) | ~430 |
| Priority 1 — clean migration path | ~290 |
| Priority 3 — needs ownership review | ~100 |
| Legacy delegation groups | ~160 |
| Legacy delegation groups actively in use | ~140 |
| New access groups to create | ~140 |
| Static/shared credentials (Secrets Safe candidates) | ~60 |

A large share of "total inventory" often turns out to be disabled accounts that don't
need migrating at all — worth filtering those out early so your Priority 1/2/3 numbers
reflect real migration effort, not noise.

## Phase 5 — Cutover & decommission

- [ ] Formal cutover date communicated to all consuming teams
- [ ] Legacy platform access revoked/disabled per your organization's decommission
      process
- [ ] Legacy platform data retained per compliance/records-retention requirements
      before final deletion
- [ ] Runbook and lessons learned captured for the next migration (this repo is a
      reasonable home for that)
