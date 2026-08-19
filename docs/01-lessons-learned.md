# Lessons Learned — Password Safe Implementation

Narrative account of a real deployment, generalized. Organized by workstream, not
strictly by calendar time, since several of these ran in parallel.

## Context

- On-premises U-Series appliance, upgraded one minor version during the engagement
  (always check release notes for UI/behavior changes mid-project — things you
  screenshot-validated on Monday can move by Friday).
- Migrating off a legacy on-prem PAM tool that had reached End of Life, across
  multiple related organizational entities sharing one appliance.
- Not yet in production at time of writing — this is a testing/migration-phase account.

## 1. Managed Accounts vs. Secrets Safe — get this distinction right early

The single most consequential early decision: **not everything belongs in a rotatable
Managed Account.**

- **Managed Accounts** are for credentials Password Safe actively owns the lifecycle
  of — it can log in and change the password on the target system. This is the right
  model for individual admin/service accounts on servers, databases, network devices, etc.
- **Secrets Safe** is for static, shared secrets that Password Safe does *not* rotate —
  legacy shared credentials, API keys, license keys, or anything where "the vendor tool
  doesn't support automated rotation for this account type" is the honest answer.

Migrating a legacy platform's shared-credential vault (dozens of accounts with no
rotation story) as Managed Accounts is the wrong move — it either fails onboarding
validation or creates rotation jobs against systems that were never designed for it.
Route those into **Secrets Safe** instead, organized into Safes/subfolders that mirror
how your teams actually think about ownership (e.g., a subfolder per admin team inside
a broader "IT Security" Safe).

**Key nuance:** Secrets Safe access is always granted **per-Safe**, regardless of
whether a user/role has Full Control at the feature level in the admin console. Feature
permissions and Safe permissions are two different gates — don't assume one implies the
other.

## 2. Bulk import: the UI's CSV importer will not do what you think

Password Safe's CSV import feature in the web UI is scoped to a **user's personal
folder**, not team/shared Safes. If your migration involves importing a few dozen
existing shared credentials into a team Safe, the UI path is a dead end.

The workaround is the **REST API** — authenticate with an API key, then `POST` the
credential data to the Secrets Safe folder/import endpoint. See
[`templates/secrets-safe-bulk-import.ps1`](../templates/secrets-safe-bulk-import.ps1)
for a working (sanitized) starting point.

Practical notes from building this:
- Store the API key as a machine-scoped environment variable on the automation host,
  not in the script.
- The automation host needs a firewall path to the appliance on TCP 443 — request this
  early, it's a standard network-change-request lead time item, not a same-day approval.
- If your legacy platform exports data in an unusual encoding, check it *before* you
  spend an afternoon debugging why field values look corrupted. RED-IM's
  `PerAccountRules.txt`, for example, is UTF-16 LE — PowerShell's default `Get-Content`
  will mangle it silently unless you pass `-Encoding Unicode`.

## 3. SAML/SSO via ADFS — the silent-failure claim mismatch

If Password Safe's **Active Directory User Mapping** type is selected for SAML, it
expects **SID-based** claims, not a `domain\groupname` string claim. This distinction
does not throw an obvious error — the SSO flow can complete, and access simply doesn't
map the way you expect (or fails to map at all), because:

- The group is sent as a name string instead of a SID, and/or
- The `SecurityIdentifier` claim comes back empty.

The fix is in ADFS's claim rules, not in Password Safe — add/adjust claim rules so the
group claim resolves to a SID before it's sent, and confirm the `SecurityIdentifier`
claim is actually populated for the test user. Validate with a claims trace, don't just
eyeball the rule — "looks right" claim rules are a common false negative here.

See [`templates/saml-adfs-claim-rules-troubleshooting.md`](../templates/saml-adfs-claim-rules-troubleshooting.md).

## 4. Environment hygiene things that will bite you if you skip them

- **OU naming precision matters.** If your AD has near-duplicate OU names (e.g. one
  with a space, one without, at different levels of the tree), Smart Rule and query
  logic will happily match the wrong one. Double-check exact OU names before building
  Smart Rules against them.
- **Test/scratch OUs will pollute production queries** if they're not explicitly
  excluded. Any OU used purely for appliance testing should be excluded from Smart Rule
  scoping once you move toward production onboarding.
- **"All Managed Systems" (or equivalent all-encompassing Smart Group) does not support
  role assignment.** This is a platform constraint, not a misconfiguration — don't
  spend time troubleshooting why a role won't attach to it; scope down to a more
  specific Smart Group instead.
- **Built-in Administrators group only accepts individual users, not AD groups.** If you
  want group-based admin access to the appliance itself, you need a separate AD group
  mapped in through the normal role-assignment path — don't expect to drop an AD group
  into the built-in local Administrators role.
- **Entitlement/access reports are scoped to a Smart Rule or Safe, not to an individual
  account.** Report cleanliness is really a function of how granular your Smart Rule
  architecture is — messy Smart Rules produce messy reports, not the other way around.

## 5. Process habits that paid off

- **Validate against screenshots, not against what the docs say should happen.**
  BeyondTrust's documentation is generally good, but UI behavior can lag or diverge
  from what's written, especially across appliance versions. When something doesn't
  match, trust the screenshot and go looking for why, rather than assuming user error.
- **Layer documentation by audience.** A confidential technical/security framework doc
  (for internal security review), a plain-language guide (for non-technical
  stakeholders and application teams), and narrow technical references (e.g. a
  firewall-rules-only doc for the network team) each get read by different people who
  need different levels of detail. One document trying to serve all three audiences
  serves none of them well.
- **One step at a time, confirmed before moving on.** Especially for anything touching
  authentication (AD binds, SAML, functional account permissions) — confirm each layer
  works in isolation before stacking the next one on top. Debugging a stack of three
  unconfirmed changes at once is much slower than debugging one.

## 6. Functional accounts must match the Managed System's Entity Type + Platform exactly

The functional account dropdown on a Managed System only shows accounts registered
with the **same Entity Type and Platform** as the target system. A service account
registered as `Asset/Windows` will never appear on an `Active Directory/Domain`
managed system's functional account dropdown, even though it's a perfectly valid AD
account. Get the Entity Type and Platform right at registration time — there's no
quick fix after the fact other than re-registering.

## 7. Workgroup mismatch is a silent onboarding blocker

If a functional account is registered with Workgroup = "None" (or any value that
doesn't match the Managed System's workgroup), it simply won't appear in that
system's functional account dropdown — no error, it just isn't in the list. Default
to the standard/default workgroup used across your managed systems unless you have a
specific reason to segment further.

## 8. Smart Rules return nothing until a discovery scan has actually run

Smart Rules only evaluate what's already in the inventory. If no discovery scan has
populated the inventory yet, a perfectly well-built Smart Rule will show zero results
— which looks identical to a misconfigured rule. Always run an IP discovery or
credentialed scan first, *then* troubleshoot the Smart Rule if it's still empty.

## 9. "Manage Account Settings" action is required even when every rotation option is off

A Managed Account Smart Rule with "Discover accounts for management" enabled will
throw an error if it doesn't also have a **Manage Account Settings** action attached —
even if every setting inside that action is toggled off. Add the action with defaults
disabled as a safe placeholder during initial validation, then turn settings on
deliberately once you're ready.

## 10. Auto Management controls portal visibility, not automatic rotation

**Enable Automatic Password Management = Yes** in the Manage Account Settings action
is what makes an account visible to requesters in the portal — it does *not* by
itself start rotating the password. Rotation only happens if a frequency/schedule is
also configured. It's easy to assume "Auto Management" means "will start rotating on
its own" when really it's closer to "eligible to be seen and requested."

## 11. LAPS-managed local accounts cannot be touched by Password Safe

If Windows LAPS (including the version built into Server 2019/2022) manages a local
account via GPO, Password Safe will fail to change that account's password with an
"account is controlled by external policy" error. Check for LAPS
(`gpresult /r | Select-String "LAPS"` on the target, or check GPO scope) *before*
onboarding local accounts for rotation — trying to manage a LAPS account is not a
misconfiguration you can fix on the Password Safe side, it's a genuine conflict
between two tools claiming the same responsibility.

## 12. Delegation groups from a legacy PAM tool often contain people, not service accounts

A common misread when migrating from a legacy platform: a delegation group like
`P_PI_DBAs` contains the **people** who are allowed to retrieve a given service
account's password — not the service account itself. The service account is
associated with the group as a delegation rule *inside* the legacy tool, not through
normal AD group membership. When mapping legacy delegation groups to new
role-based-access groups, keep the direction of the relationship straight: same
people, new group, new platform — not "convert the group into the account."

## 13. Wide-character encoding in legacy exports is a common silent-corruption source

If your legacy platform exports data from a Windows-native tool, don't assume
UTF-8. Some older tools (Lieberman/RED-IM's `PerAccountRules` export, for example)
write UTF-16 LE — every character followed by a null byte. PowerShell's default
`Get-Content` will "succeed" but silently mangle the data. Use
`Get-Content -Encoding Unicode` and strip null bytes (`-replace '\x00',''`) when
parsing exports like this, and verify a sample row manually before trusting a bulk
parse.

## 14. A 401 from the API sign-in endpoint doesn't always mean a bad key

The single most useful discovery from a Secrets Safe API proof-of-concept: an API Key
Policy registration existing and being active is **not sufficient by itself**. The
BeyondInsight group containing the `runas` user also needs that API registration
explicitly assigned/selected in User Management. Skip that step and every sign-in call
returns HTTP 401 with `Failed to authenticate due to one or more authentication
rules.` — which reads exactly like a bad or expired key.

Before assuming the key is the problem, check (in this order): the API registration
is active → the registration is assigned to the correct group → the `runas` user is a
member of that group → then look at IP/authentication-rule restrictions. The key
itself is rarely the actual cause once the registration is confirmed active.

## 15. Owner objects need `UserId`/`GroupId`, not a generic `Id`, and require API v3.1

Creating a Secrets Safe secret with an `Owners` collection returns HTTP 400 (`Invalid
OwnerType`) unless: the request targets **API version 3.1** (`?version=3.1` on the
create-secret call), `OwnerType` is explicitly set (`User` or `Group`), and each object
in `Owners` uses `UserId` or `GroupId` — a generic `Id` property is silently rejected.
JSON property *order* doesn't matter for this endpoint; property *names* and nesting
do.

## 16. Treat any API key that touched a terminal, screenshot, or transcript as exposed

If a key was ever visible in interactive troubleshooting output — printed to a
console, pasted into a chat transcript, captured in a screenshot, or left in shell
history — rotate it and restore any authentication rules (e.g. explicit source-IP
restrictions) that were relaxed for testing, even if you're confident nobody else saw
it. This is a "treat it as burned, don't audit whether it's actually burned" policy —
cheaper than being wrong about who had visibility. Never print `$headers`,
`$headers.Authorization`, or a `$Session` object during any recorded or shared
troubleshooting session — all three can carry the Authorization header or session
token.

## Open items / still in progress at time of writing

- Formal break-glass procedure (see [`runbooks/break-glass-procedure-template.md`](../runbooks/break-glass-procedure-template.md) for a starting template — this should exist *before* go-live, not be reactively written after a lockout).
- SAML/SSO resolution pending ADFS claim rule fix from the identity team.
- Firewall approvals for both the API automation path and the broader managed-systems subnet.
- Full production cutover from the legacy platform once the pilot Safe and bulk import are validated end-to-end.
