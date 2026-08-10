# Discovery & Import Checklist

## Before running discovery

- [ ] Pilot scope defined (hostnames, AD OU distinguishedName, or CIDR range — cap the
      first pass at a small, low-risk set)
- [ ] Discovery method chosen: appliance/scanner discovery vs. connector/agent-based
- [ ] Functional/discovery account confirmed to exist with least-privilege scope for
      the target platform(s)
- [ ] Discovery job set to report-only/staging mode for the first run
- [ ] Test/scratch OUs explicitly excluded from scope

## After discovery runs

- [ ] Job completed without errors
- [ ] Discovered system/account count roughly matches expectation for the pilot scope
- [ ] No unexpected systems appeared outside the intended scope (check Address
      Group/Smart Rule boundaries)
- [ ] Results exported for review (redact anything sensitive before sharing outside the
      immediate team)

## Classifying discovered accounts (Managed Account path)

For each account, decide and record:

- [ ] Safe/Smart Group assignment
- [ ] Owner (person or team)
- [ ] Classification (High/Medium/Low — see suggested defaults below)
- [ ] Rotation policy
- [ ] Approval policy (none / single approver / multi-approver)
- [ ] Plaintext display allowed? (default to **no** for High classification)

**Suggested defaults** (adjust to your org's risk tolerance):

| Classification | Plaintext | Approval | Session recording |
|---|---|---|---|
| High | No | Required | Required |
| Medium | Optional | Single approver | Recommended |
| Low | Allowed | None (automated rotation) | Optional |

## Classifying discovered/migrated secrets (Secrets Safe path)

Static/shared credentials that don't fit the rotatable Managed Account model:

- [ ] Confirm the credential genuinely cannot/should not be auto-rotated (if it can be,
      reconsider the Managed Account path instead)
- [ ] Target Safe/subfolder identified, matching how the owning team actually organizes
      access
- [ ] Owner/team confirmed
- [ ] If bulk-importing more than a handful of secrets into a team Safe, use the REST
      API path (`templates/secrets-safe-bulk-import.ps1`), not the UI CSV importer

## Approval gate

- [ ] **Before importing more than ~50 accounts/secrets into a production Safe,
      require explicit sign-off** from the platform owner — don't let a bulk import
      script quietly promote a large batch straight to production scope.

## Verification after import

- [ ] Sample of imported items visible in the target Safe with correct classification
- [ ] Owner and policy correctly attached
- [ ] Spot-check that Safe-level permissions match intended access, independent of any
      feature-level admin permissions
