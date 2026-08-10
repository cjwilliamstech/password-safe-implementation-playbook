# Smart Rule Examples (Generic Patterns)

Common Smart Rule patterns worth having as a starting point. Adjust criteria/operators
to match your version's Smart Rule builder UI.

## By platform type

- **All Windows Servers** — Platform = Windows, excludes desktop OS
- **All Linux/Unix Servers** — Platform = Linux/Unix family
- **All Database Instances** — Platform in [Oracle, MS SQL Server, MySQL, PostgreSQL]

## By organizational scope (AD OU-based)

- **Production Windows Servers** — Platform = Windows AND OU = `OU=Servers,OU=Production,DC=<domain>`
  - ⚠️ Double-check exact OU spelling/spacing. Near-duplicate OU names at different
    tree levels (e.g. one with a trailing space, one without) are a common source of
    Smart Rules silently matching the wrong set.
- **Exclude Test/Scratch Systems** — NOT OU = `OU=Test,DC=<domain>` (combine with other
  rules as an exclusion filter once you move toward production scope)

## By account role

- **Service Accounts — Rotated** — Account is member of AD group `<Service-Accounts-Rotated>`
- **Service Accounts — Non-Rotated (route to Secrets Safe instead)** — Account is
  member of AD group `<Service-Accounts-Non-Rotated>`
- **Human/Delegated-Access Accounts** — Account is member of a group representing
  human admins with delegated access, as distinct from true service accounts — useful
  to separate these when scoping Smart Rules, since they behave differently for
  rotation and ownership purposes.

## Database-specific

- **Oracle DBA-managed accounts** — Platform = Oracle AND Account is member of AD group
  `<Oracle-DBA-Group>` — useful for scoping a DBA team's visibility to only the database
  accounts relevant to them, separate from OS-level Windows/Linux accounts on the same
  hosts.

## Manage Account Settings — reasonable starting defaults

Every Managed Account Smart Rule that discovers accounts for management needs a
"Manage Account Settings" action attached (see lessons-learned #9 — it errors without
one, even if every setting inside is off). Reasonable starting point for service
accounts:

| Setting | Value | Reason |
|---|---|---|
| Enable Automatic Password Management | Yes | Required for portal visibility — see lessons-learned #10, this is not the same as automatic rotation |
| Change Password Frequency | Every 365 Days (adjust to your policy) | Annual rotation is a common service-account baseline; tighten for higher-risk accounts |
| Change Password Time | Off-hours (e.g. 23:30) | Avoids rotating mid-business-day |
| Default Release Duration | 2 hours | Enough for most routine tasks |
| Maximum Release Duration | 8 hours | Full business day ceiling |
| Change Password After Release | No, for service accounts with no rotation-on-checkout requirement | Yes, for higher-sensitivity accounts where you want a fresh credential every checkout |
| Max Concurrent Requests | 1 | One checkout at a time per account, simplifies audit trail |

## Three-tier model diagram

See [`docs/04-architecture-decisions.md`](../docs/04-architecture-decisions.md) for
the full Directory Query → Smart Rule → Smart Group → Access Group → Access Policy
diagram and the reasoning behind splitting it into three tiers.

## Known constraint

An "All Managed Systems" (or similarly named catch-all) Smart Group typically does
**not** support direct role assignment in Password Safe — this is a platform
limitation, not a misconfiguration. If you need broad role coverage, build a Smart Rule
that's inclusive-but-specific (e.g. "all platforms, all in-scope OUs") rather than
relying on the built-in catch-all group.

## Staged rollout pattern

1. Build the Smart Rule.
2. Confirm membership matches expectations by reviewing the resulting Smart Group
   contents before attaching any policy or auto-onboard behavior.
3. Attach Access Policy / role assignment.
4. Only enable auto-onboard (if your version supports it) after the above has been
   validated manually at least once.
