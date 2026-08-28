# Lessons Learned

Field notes from a real Password Safe implementation, one lesson per file. Numbered
roughly in the order they were discovered (so the numbering reads like a project
timeline), but grouped below by topic so you can jump straight to what you're looking
for rather than scanning chronologically.

## Secrets & account model fundamentals

| # | Lesson |
|---|---|
| [01](01-managed-accounts-vs-secrets-safe.md) | Managed Accounts vs. Secrets Safe — get this distinction right early |
| [02](02-ui-csv-import-personal-folders-only.md) | The UI's CSV importer only works for personal folders, not team Safes |

## Smart Rules, OUs & access scoping

| # | Lesson |
|---|---|
| [04](04-ou-naming-precision-in-smart-rules.md) | OU naming precision matters — near-duplicate names silently mis-scope Smart Rules |
| [05](05-test-ous-must-be-excluded-from-production-scope.md) | Test/scratch OUs will pollute production Smart Rules if not explicitly excluded |
| [06](06-all-managed-systems-smart-group-no-role-assignment.md) | The "all systems" catch-all Smart Group doesn't support role assignment |
| [07](07-built-in-admin-group-requires-individual-users.md) | The built-in local Administrators role may only accept individual users, not AD groups |
| [08](08-entitlement-reports-scoped-to-smart-rule-or-safe.md) | Entitlement/access reports are scoped to a Smart Rule or Safe, not a single account |
| [14](14-smart-rules-empty-until-discovery-scan-runs.md) | Smart Rules return nothing until a discovery scan has actually run |
| [15](15-manage-account-settings-action-required.md) | The "Manage Account Settings" action is required even with every setting off |
| [16](16-auto-management-controls-portal-visibility-not-rotation.md) | Auto Management controls portal visibility, not automatic rotation |

## Functional accounts & platform prerequisites

| # | Lesson |
|---|---|
| [12](12-functional-account-entity-type-platform-match.md) | Functional accounts must match the Managed System's Entity Type + Platform exactly |
| [13](13-workgroup-mismatch-silent-onboarding-blocker.md) | Workgroup mismatch is a silent onboarding blocker |
| [17](17-laps-accounts-cannot-be-managed-by-password-safe.md) | LAPS-managed local accounts cannot be touched by Password Safe |

## Legacy migration & data handling

| # | Lesson |
|---|---|
| [18](18-legacy-delegation-groups-contain-people-not-accounts.md) | Legacy delegation groups often contain people, not service accounts |
| [19](19-utf16-encoding-in-legacy-exports.md) | Wide-character encoding in legacy exports is a common silent-corruption source |
| [23](23-bulk-account-creation-password-seeding.md) | Bulk Managed Account creation — seeding the current password to avoid a forced mass rotation |

## SAML / SSO

| # | Lesson |
|---|---|
| [03](03-saml-adfs-sid-claim-mismatch.md) | SAML/SSO via ADFS — the silent-failure SID claim mismatch |

## API authentication & scripting

| # | Lesson |
|---|---|
| [20](20-api-401-not-always-a-bad-key.md) | A 401 from the API sign-in endpoint doesn't always mean a bad key |
| [21](21-owner-schema-requires-userid-groupid-and-api-v31.md) | Owner objects need UserId/GroupId, not a generic Id, and require API v3.1 |
| [22](22-treat-exposed-api-keys-as-compromised.md) | Treat any API key that touched a terminal, screenshot, or transcript as exposed |
| [24](24-api-runas-domain-format-401.md) | A silent 401 traced to NetBIOS vs. FQDN in the `runas` claim |
| [25](25-whatif-propagation-suppresses-reporting.md) | `-WhatIf` silently suppressed the diagnostic report, not just the risky action |
| [26](26-surface-api-error-bodies-not-status-codes.md) | Every 4xx error looked identical until the API's own response body was extracted |
| [27](27-system-level-auto-management-and-linked-account-anchor.md) | A system-level setting blocked every account-level rotation flag, and "linking" needed a deliberate anchor choice |

## Process habits

| # | Lesson |
|---|---|
| [09](09-validate-against-screenshots-not-docs.md) | Validate against screenshots, not against what the docs say should happen |
| [10](10-layer-documentation-by-audience.md) | Layer documentation by audience — one document can't serve all readers well |
| [11](11-one-step-at-a-time-before-stacking-changes.md) | Confirm one layer works before stacking the next, especially for auth |

---

*Numbering has a couple of intentional gaps (no lesson 00, jumps between groups) —
that's from splitting an earlier combined document into individual files and merging
in a second batch. Not worth renumbering; the content is what matters.*
