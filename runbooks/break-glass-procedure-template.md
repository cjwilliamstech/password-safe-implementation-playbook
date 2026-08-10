# Break-Glass Access Procedure (Template)

Draft this **before go-live**, not reactively after an actual lockout. Fill in the
bracketed sections for your environment and route through your normal change/security
review process before treating it as final.

## Purpose

Defines the emergency access path to the Password Safe appliance when normal
authentication (AD/SSO) is unavailable — e.g. AD outage, SAML/SSO misconfiguration,
network partition to the identity provider.

## Break-glass account

- **Account name:** `<break-glass-local-account>`
- **Account type:** Local appliance account, not tied to AD/SSO
- **Storage of credential:** `<where the credential itself is stored — e.g. a sealed
  physical envelope in a controlled location, or a separate emergency-access vault not
  dependent on this platform's own availability>`
- **Who can authorize use:** `<named roles/individuals — e.g. IT Security Admin +
  one designated backup>`

## When to use

- [ ] AD authentication is confirmed down (not just slow) for the appliance's bind path
- [ ] SSO/SAML is confirmed misconfigured or unavailable
- [ ] Normal admin accounts are locked out or otherwise unavailable
- [ ] `<other org-specific triggers>`

## Procedure

1. Confirm and document the outage/lockout condition (screenshot/error, timestamp).
2. Notify `<escalation contact/role>` before using the break-glass account.
3. Retrieve the break-glass credential per the storage process above.
4. Log in to the appliance directly (not via SSO) using the break-glass account.
5. Perform only the minimum action needed to restore normal access (e.g. fix the SAML
   claim rule, re-enable a locked admin account) — the break-glass account should not
   be used for routine administration.
6. Log out.
7. **Rotate the break-glass credential immediately after use.**
8. Document the incident: what failed, what was done, who authorized it, and the
   rotation confirmation.

## Post-use requirements

- [ ] Credential rotated
- [ ] Incident logged in `<your incident tracking system>`
- [ ] Root cause of the normal-auth failure identified and remediated
- [ ] Break-glass procedure reviewed for any gaps surfaced by the actual use

## Review cadence

- [ ] Test the break-glass procedure (without making real changes) on a `<quarterly /
      semi-annual>` cadence to confirm the credential still works and the storage
      location is still accurate
- [ ] Review this document whenever the SSO/IdP configuration changes materially
