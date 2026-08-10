# SAML/SSO via ADFS — Claim Rules Troubleshooting

Reference: https://docs.beyondtrust.com/bips/docs/pathfinder-configure-saml

## Symptom

SSO login completes without an obvious error, but group-based role mapping doesn't
work as expected — users land without the roles/access their AD group membership
should grant.

## Root cause pattern

If Password Safe's **User Mapping** type is set to **Active Directory**, it expects
group claims in **SID** form. The most common misconfiguration:

- ADFS sends the group claim as a plain string (`DOMAIN\GroupName`) instead of a SID, and/or
- The `SecurityIdentifier` claim is present in the rule set but resolves empty for the
  test user

This fails **silently** from the Password Safe side — there's no clear "claim
mismatch" error, just access that doesn't map the way you'd expect.

## Diagnostic steps

1. In ADFS, run a claims trace (or use your IdP's equivalent debug/test tooling) for
   the test user's SSO session.
2. Inspect the outgoing claims: confirm whether the group claim is a SID
   (`S-1-5-21-...`) or a name string.
3. Confirm the `SecurityIdentifier` claim is actually populated, not just present as an
   empty rule.
4. Cross-check Password Safe's SAML configuration for the selected **User Mapping**
   type — Active Directory mapping requires the SID form; other mapping types may not.

## Fix

Adjust the ADFS claim rules (not the Password Safe side) so the relevant group
claim(s) resolve to SID form before being sent, and that `SecurityIdentifier` is
populated. Typical approach:

- Use a claim rule template that converts group membership to a SID-based claim
  (ADFS has built-in templates for "Send Group Membership as a Claim" — confirm the
  claim type selected is SID, not a custom string type).
- Re-run the claims trace after the change and confirm the SID now appears correctly
  before re-testing the actual Password Safe login.

## Validation checklist

- [ ] Claims trace shows a populated `SecurityIdentifier` claim
- [ ] Group claim value is in SID form, not a name string
- [ ] Test user's Password Safe login reflects the expected role/access after the fix
- [ ] Re-test with a second user in a different group to confirm the fix generalizes,
      not just for the one account used during debugging
