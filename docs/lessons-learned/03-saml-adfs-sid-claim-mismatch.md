# Lesson: SAML/SSO via ADFS — the Silent-Failure SID Claim Mismatch

If Password Safe's **User Mapping** type is set to **Active Directory** for SAML, it
expects group claims in **SID** form, not a `domain\groupname` string claim. This
distinction does not throw an obvious error — the SSO flow can complete, and access
simply doesn't map the way you expect (or fails to map at all), because:

- The group is sent as a name string instead of a SID, and/or
- The `SecurityIdentifier` claim comes back empty.

The fix is in ADFS's claim rules, not in Password Safe — add/adjust claim rules so the
group claim resolves to a SID before it's sent, and confirm the `SecurityIdentifier`
claim is actually populated for the test user. Validate with a claims trace, don't
just eyeball the rule — "looks right" claim rules are a common false negative here.

See [`templates/saml-adfs-claim-rules-troubleshooting.md`](../../templates/saml-adfs-claim-rules-troubleshooting.md)
for the full diagnostic checklist.
