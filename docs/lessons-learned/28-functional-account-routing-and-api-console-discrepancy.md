# Lesson: A Test Account's Failed Rotation Traced Through Three Layers — a Bad API Field Assumption, a Wrong System-Level Default, and an API/Console UI Discrepancy

## What I Was Trying to Do

Validate that two newly bulk-imported test Managed Accounts — created via
API with a seeded password and an individual rotation schedule — would
actually rotate successfully on their first real scheduled change, not
just pass creation.

## What Happened

The scheduled rotation failed with a clear AD-level error:

```
FunctionalAccount=(AccountName=[BIND-ACCOUNT], ...)
Password change failed. Error: Exception has been thrown by the target
of an invocation. Access is denied. (0x80070005 (E_ACCESSDENIED))
NumberOfFailures has reached configured maximum=3
```

The account had been created with a functional account explicitly
specified in the request body — but the log showed rotation was actually
attempted using a completely different, read-only bind account instead.

## Root Cause (Layer 1): `FunctionalAccountID` Is Not a Valid Field on Managed Accounts

Re-checking the Password Safe API schema for
`POST ManagedSystems/{systemID}/ManagedAccounts` confirmed
`FunctionalAccountID` is **not one of the accepted fields** on that
object. It only exists at the parent Managed System / Directory level
(`GET/PUT Directories/{id}`). The import script had included it in the
per-account request body anyway — the API silently ignored it rather than
rejecting the request, so there was no error at creation time to signal
the value was meaningless there. Rotation actually uses whatever
functional account is configured on the parent Directory, which in this
case was still set to the original read-only bind account — apparently
never updated after a dedicated rotation-purpose functional account was
created later in the project.

This also explained why earlier, unrelated account onboarding (via a
Directory Query + Smart Rule discovery path, not direct API creation) had
rotated successfully: that path's "Manage Account Settings" Smart Rule
action lets you specify a functional account *at the Smart Rule level*,
overriding the system default. Direct API-created accounts have no such
override available and fall straight through to the system default.

## Root Cause (Layer 2): The API Accepted a Fix That the Server Silently Ignored

Attempting to correct the Directory's `FunctionalAccountID` via
`PUT Directories/{id}` returned `200 OK` with the corrected value
reflected in the response body — but a subsequent `GET` on the same
object showed the old value unchanged. Repeating the PUT with explicit
verification (printing the outgoing JSON body, checking the field
directly in memory before sending) confirmed the request genuinely sent
the correct value and the server's own response echoed it back correctly
— yet the persisted state never changed. Two required validation errors
surfaced along the way (`ForestName is required`, `NetBiosName is
required`) that hadn't been obvious from the initial `GET`, since those
fields were blank on the existing record and only enforced on write.

The actual fix was only achieved through the **console UI**: Managed
Systems → [the Directory] → Functional Account tab → selecting the
correct account → clicking **Update Functional Account** explicitly (even
though the dropdown appeared to already show the correct account
selected). This strongly suggests the console's save action goes through
a different code path than a raw `PUT Directories/{id}` call for this
specific field — the two are not interchangeable for this purpose,
despite both nominally targeting the same object.

## A Related, Separate Finding: OU-Level AD Delegation Can Fail Identically

After correcting the Directory-level functional account, one of the two
test accounts (sitting in a different company's OU than the other)
**still** failed rotation with the same "Access is denied" pattern. This
turned out to be a distinct, already-tracked issue: the corrected
functional account lacked delegated Reset Password permission on that
specific OU. The two failure modes — wrong functional account entirely,
versus correct functional account lacking OU-level delegation — produce
visually identical AD access-denied errors in the rotation log, which
could easily send someone chasing the wrong fix if the two aren't
distinguished carefully.

## What I Did to Fix It

- Corrected the Directory's functional account via the console UI (the
  only path confirmed to actually work), and verified via API `GET`
  afterward that the change had genuinely persisted this time.
- Removed `FunctionalAccountID` entirely from the script's per-account
  request body, with an inline comment explaining why it doesn't belong
  there, so it can't be silently reintroduced by a future edit.
- Added a pre-flight validation step to the import script:
  `Test-DirectoryRotationConfig` reads the target Directory's actual
  `AutoManagementFlag` and `FunctionalAccountID` via `GET Directories/{id}`
  **before creating any accounts**, and stops the entire run with an
  explicit, actionable error (including the exact console navigation
  path) if either doesn't match what's expected — rather than letting a
  whole batch of accounts get created against a misconfigured system and
  discovering it later, one failed scheduled rotation at a time.
- Documented explicitly, in both the script and here, that this pre-flight
  check cannot detect OU-level delegation gaps — only the Directory-wide
  functional account misconfiguration. A clean pre-flight pass is a
  necessary check, not a sufficient guarantee that every account will
  rotate successfully.

## What I Would Do Differently

I would have validated the request body against the actual current API
schema line-by-line before ever using `FunctionalAccountID` in it, rather
than assuming a field name that sounded plausible was accepted just
because the API didn't error on it. An API silently ignoring an unknown
field is a much more dangerous failure mode than rejecting it outright —
it produces working-looking output right up until a downstream process
(rotation, in this case) reveals the gap, often much later and in a much
less obvious way.

I would also default to verifying any "fix" applied via a direct API PUT
with an independent read-back in the same session, immediately — not
after using a `-WhatIf`-style dry run's success as implicit confirmation.
A `200 OK` response confirms the server accepted and parsed the request;
it does not confirm the server actually committed the change.

## Key Takeaway

An API accepting a field without error is not the same as an API using
that field. And an API accepting a write request with a `200` is not the
same as that write actually persisting. Both gaps are invisible until you
explicitly check for them — verify against the documented schema before
trusting a field's effect, and verify with an independent read-back before
trusting a write's effect, especially for configuration that many
downstream accounts will silently depend on.
