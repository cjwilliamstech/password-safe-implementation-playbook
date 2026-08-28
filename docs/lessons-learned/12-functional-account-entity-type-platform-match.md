# Lesson: Functional Accounts Must Match the Managed System's Entity Type + Platform Exactly

The functional account dropdown on a Managed System only shows accounts registered
with the **same Entity Type and Platform** as the target system. A service account
registered as `Asset/Windows` will never appear on an `Active Directory/Domain`
managed system's functional account dropdown, even though it's a perfectly valid AD
account.

**Takeaway:** get the Entity Type and Platform right at registration time — there's no
quick fix after the fact other than re-registering.
