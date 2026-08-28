# Lesson: Bulk Managed Account Creation — Seeding the Current Password to Avoid a Forced Mass Rotation

## What I Was Trying to Do

Migrate several hundred legacy-managed service accounts into Password Safe as
Managed Accounts, with two constraints that don't usually appear together:

1. Each account has its own after-hours rotation window, dictated by
   individual system/application impact tolerance and account owner
   availability — no single global rotation schedule fits the fleet.
2. We wanted to avoid a mass forced rotation on day one. Password Safe has
   no knowledge of an account's current password at onboarding by default,
   so the naive path (onboard, then let the first scheduled rotation set a
   known-good password) would have meant every migrated account's real
   first rotation happened on an arbitrary, unplanned date — exactly the
   kind of uncoordinated change the business-impact constraint above was
   meant to prevent.

## What Happened

There is no native UI bulk-import for Managed Accounts (unlike Secrets
Safe, which has a CSV import path for personal folders). Bulk creation has
to go through the REST API, one `POST` per account. That part was expected.
What wasn't obvious going in was how much could be set in that single
create call — full rotation schedule *and* the current password — versus
how much still had to happen as a separate step or wasn't controllable at
all from the account level.

## Root Cause

`POST ManagedSystems/{systemID}/ManagedAccounts` accepts `Password`,
`AutoManagementFlag`, `FunctionalAccountID`, `ChangeFrequencyType`,
`ChangeFrequencyDays`, `ChangeTime`, and `NextChangeDate` all in the same
request body. Seeding the current password at creation means Password
Safe's record matches the live system from minute one — no forced first
rotation required just to establish a known-good password. The per-account
schedule fields meant each account's actual after-hours window could be
respected individually, rather than forcing a fleet-wide compromise
schedule.

The catch: seeding is only as good as the export it came from. If the
source password had changed since the export was pulled, Password Safe
would silently store a wrong value with no way to know until the account
was actually requested. `POST ManagedAccounts/{id}/Credentials/Test`
closes that gap — it validates the seeded password against the live
system immediately after creation, without changing it, converting a
silent future failure into an immediate, visible result.

## What I Did to Fix It

- Built a script that creates each account with the full rotation schedule
  embedded at creation time, sourced from a per-row CSV
  (`ChangeFrequencyDays`, `ChangeTime`, `NextChangeDate` all per-account,
  not global script parameters).
- For any account flagged to be seeded, immediately followed the create
  call with `Credentials/Test` and recorded the result (`Yes` /
  `NO - MISMATCH`) directly in the run's report, so a stale export shows
  up as a clear flag rather than a future support ticket.
- Deliberately kept the password source as a same-day, narrow-exposure
  export rather than a long-lived credential store — the export is loaded
  into memory once, converted to `SecureString` immediately, and the file
  itself is only ever touched by the script for the duration of a single
  run (see lesson on the export lifecycle, below, if broken out
  separately).

## What I Would Do Differently

I'd build the `Credentials/Test` validation step in from the very first
draft of the script, not add it after the fact. It's cheap (one extra API
call per seeded account) and it's the single piece of evidence that
answers the question that actually matters: "did seeding work, or did we
just create an account with a wrong password and a false sense of
security?"

## Key Takeaway

Bulk API account creation can fully replace the "onboard now, fix the
password later" pattern — but only if you also validate what you seeded.
Creation without validation just moves the discovery of a stale password
from "day one, obviously" to "whenever someone tries to check it out,
confusingly."
