# AD/IdP Group → Password Safe Role Mapping Template

Fill in per environment. Keep the naming convention consistent so future admins can
tell at a glance what a group is for.

| AD/IdP Group | Password Safe Role | Scope (Safe / Smart Group) | Notes |
|---|---|---|---|
| `<PWS-Admins>` | Full administrative role (Features, Smart Groups, Password Safe roles — Full Control) | Global | Maintain as a dedicated AD group; built-in local Administrators-equivalent role may only accept individual users, not groups, depending on version |
| `<PWS-Requestors-TeamA>` | Requestor | Team A's Safe(s)/Smart Group | |
| `<PWS-Approvers-TeamA>` | Approver | Team A's Safe(s)/Smart Group | |
| `<PWS-Injectors-TeamA>` | Inject-only session access | Team A's Safe(s)/Smart Group | No plaintext credential visibility |
| `<PWS-Auditors>` | View/Audit (read-only) | Global or per-Safe | For compliance/security review access |
| `<PWS-Oracle-DBAs>` | Requestor/Manager scoped to Oracle accounts | Oracle-specific Smart Group | Example of a platform-specific delegated group |

## Guidance

- One group per role per scope, not one broad group with mixed permissions — makes
  access reviews far easier later.
- Test every new mapping with exactly one real test user before adding the rest of the
  intended membership.
- Revisit this table on your access-review cadence (e.g. quarterly) alongside
  BeyondInsight's entitlement/access reporting.
