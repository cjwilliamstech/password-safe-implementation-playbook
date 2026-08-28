# Lesson: Confirm One Layer Works Before Stacking the Next, Especially for Auth

Especially for anything touching authentication (AD binds, SAML, functional account
permissions) — confirm each layer works in isolation before stacking the next one on
top.

**Takeaway:** debugging a stack of three unconfirmed changes at once is much slower
than debugging one. This is doubly true for auth, where failures are often silent or
generic (see [lesson 20](20-api-401-not-always-a-bad-key.md) for a concrete example).
