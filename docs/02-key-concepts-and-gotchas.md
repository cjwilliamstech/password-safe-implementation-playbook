# Key Concepts & Gotchas

Quick-reference explanations of Password Safe concepts that are easy to misuse if you're
new to the platform, written from direct implementation experience. UI labels match the
official docs (https://docs.beyondtrust.com/bips/docs/welcome-to-password-safe) — always
confirm against the current version, as labels/behavior shift between releases.

## Core object model (how the pieces fit together)

- **Managed System** — a target asset/platform Password Safe knows about (a server, a
  database instance, a network device, a directory, etc.).
- **Managed Account** — a credential on a Managed System that Password Safe can log in
  as and rotate. This is the "actively managed" credential model.
- **Functional Account** — a service account Password Safe itself uses to perform
  actions against a platform (e.g., an account with local admin rights used to change
  other accounts' passwords on Windows hosts). Not the same as a Managed Account —
  functional accounts are infrastructure for Password Safe's own operation.
- **Smart Rule** — a saved query/filter that dynamically groups Managed Systems/Accounts
  based on criteria (OU, platform type, naming pattern, etc.).
- **Smart Group** — the resulting dynamic group produced by a Smart Rule; used as the
  scoping unit for role/policy assignment.
- **Address Group** — a named collection of network ranges/addresses, typically used to
  scope discovery or Smart Rules by network location.
- **Access Policy** — governs *how* access to a credential/session can happen: approval
  requirements, time windows, MFA step-up, max checkout duration, whether plaintext
  display is allowed vs. injection-only.
- **Safe** — a Secrets Safe container for static secrets, permissioned independently of
  the broader feature-level admin permissions.

## Secrets Safe vs. Managed Accounts (see also lessons-learned doc)

| | Managed Account | Secrets Safe entry |
|---|---|---|
| Password Safe rotates it | Yes | No |
| Typical use case | Individual admin/service account on a live system | Static shared credential, API key, license key |
| Permission model | Smart Group / Access Policy | Per-Safe, independent of feature-level Full Control |
| Bulk import via UI CSV | N/A (different onboarding flow) | Personal-folder only — team Safes need the REST API |

## SAML / SSO — Active Directory User Mapping mode

When Password Safe's User Mapping type is set to Active Directory, group membership
resolution expects claims in **SID** form. If your IdP is sending group membership as a
plain name string (`DOMAIN\GroupName`), or if the `SecurityIdentifier` claim is empty,
mapping will not work correctly — and importantly, this frequently fails *silently*
rather than throwing a clear SSO error. Always:

1. Confirm the IdP's claim rules emit a SID-based group claim.
2. Confirm `SecurityIdentifier` is actually populated for a test user (use your IdP's
   claims trace/debug tooling).
3. Only then troubleshoot on the Password Safe side.

## Firewall planning

Password Safe needs bidirectional-feeling but actually mostly outbound-from-appliance
connectivity: the appliance (PS Nodes) needs to reach *out* to managed systems on
platform-specific ports (WinRM/SMB for Windows, SSH for *nix, database-native ports for
DB platforms, etc.), while inbound to the appliance is mostly the web UI (443) and
session protocols (RDP/SSH proxy ports) from the user population. See
[`templates/firewall-rules-reference.md`](../templates/firewall-rules-reference.md) for
a full generic table — pull this into your network change request early, since these
tend to go through a formal approval queue with lead time.

## Reporting

Entitlement and access reports are scoped to a **Smart Rule or a Safe** — not to an
individual account. If your Smart Rules are broad/messy, your reports will be too. Treat
Smart Rule architecture as a reporting-design decision, not just an onboarding
convenience.

## Access Policy — a reasonable starting pattern for service accounts

Access Policies control *how* an approved request can be used, separate from *whether*
it's approved. A workable default for routine service-account checkout, where the goal
is audit trail rather than friction:

| Setting | Suggested value | Why |
|---|---|---|
| Schedule | All day, recurring, daily | Service accounts get used at any hour |
| Multi-day checkout | Disabled | Forces re-request, keeps audit trail granular |
| View Password | Enabled (or disabled if injection-only) | Depends on your injection strategy |
| Auto Approve | Enabled for low-risk service accounts | Reduces friction for routine access |
| Reason Required | Enabled | Every checkout gets a documented justification — this one setting does more for audit readiness than almost anything else in the platform |
| RDP / SSH / Application session launch | Disabled unless the use case specifically needs it | Don't enable session-launch capability by default just because it exists |

**Why Reason Required matters more than it looks:** for compliance reviews (quarterly
audits, access recertification, etc.), being able to show *who retrieved which
credential, when, and why* for every single checkout is usually the actual evidence an
auditor wants — not just that rotation happened.

## Console navigation quick reference

| Task | Path (adjust to your version's menu layout) |
|---|---|
| Functional Accounts | Configuration → Privileged Access Management → Functional Accounts |
| Smart Rules | Configuration → General → Smart Rules |
| Managed Systems | Left menu → Managed Systems |
| Managed Accounts | Left menu → Managed Accounts |
| Address Groups | Configuration → Discovery Management → Address Groups |
| Directory Queries | Configuration → Role Based Access → Directory Queries |
| Access Policies | Configuration → Privileged Access Management Policies → Access Policies |
| User Management | Configuration → Role Based Access → User Management |
| Secrets Safe | Left menu → Secrets Safe icon |
| Discovery Scans | Top-right Quick Navigation → Discovery Scans |
| User Audits | Configuration → General → User Audits |
| Analytics & Reporting | Left menu → Analytics & Reporting icon |

Menu paths shift between releases more than most other UI elements — treat this table
as "roughly where to look," not gospel, and confirm against your installed version.
