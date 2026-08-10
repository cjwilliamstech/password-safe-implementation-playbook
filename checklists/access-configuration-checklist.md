# Access Configuration Checklist

## Roles & groups

- [ ] AD/IdP groups exist for each role: Requestors, Approvers, Vault
      Operators/Administrators, Auditors, Injectors (adjust names to your org's
      convention)
- [ ] Each group mapped to the correct Password Safe role with least-privilege scope
- [ ] Mapping tested with one real user per group before broader rollout
- [ ] Built-in local Administrators-equivalent role: confirm whether it accepts groups
      or only individual users in your version — plan admin access accordingly

## Safes

- [ ] Safe(s) created for the pilot/rollout wave
- [ ] Permission levels set deliberately per Safe: Request/Checkout, Approve, Manage,
      Inject-only, View/Audit
- [ ] Confirmed Safe-level permissions are independent of feature-level Full Control —
      don't assume a Full Control admin automatically sees Safe contents

## Access Policies

- [ ] Approval requirements defined (none / single / multi-approver)
- [ ] Allowed time windows / days defined if applicable
- [ ] MFA step-up configured for sensitive checkouts
- [ ] Maximum checkout duration set
- [ ] Policy attached to the correct Requester group or Safe

## Smart Rules / Smart Groups (for Managed Accounts)

- [ ] Smart Rules scoped precisely — double-check exact OU names (near-duplicate names
      with subtle differences, e.g. a trailing space or slightly different casing, are
      a common source of silent mis-scoping)
- [ ] Test/scratch OUs excluded
- [ ] Confirmed the "all systems" catch-all Smart Group (if one exists in your version)
      is **not** relied on for role assignment — platform constraint, scope down instead
- [ ] Auto-onboard smart rules kept in staging/report-only mode until access policies
      are validated

## SAML / SSO (if applicable)

- [ ] IdP identified (ADFS, Azure AD, Okta, etc.)
- [ ] User Mapping type in Password Safe matches what the IdP is actually sending
      (Active Directory mapping requires SID-based group claims — see
      [`templates/saml-adfs-claim-rules-troubleshooting.md`](../templates/saml-adfs-claim-rules-troubleshooting.md))
- [ ] Test login validated end-to-end with a real test user before rollout

## Verification

- [ ] Test Requester sees Request/Checkout action for an in-scope Safe/account
- [ ] Test Approver receives and can act on a request
- [ ] Test Injector can launch a session without seeing the underlying credential
- [ ] Access attempted outside policy (wrong time window, missing MFA, etc.) is
      correctly blocked
