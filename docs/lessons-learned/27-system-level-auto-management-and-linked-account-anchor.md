# Lesson: A System-Level Setting Blocked Every Account-Level Rotation Flag, and "Linking" Needed a Deliberate Anchor Choice

## What I Was Trying to Do

Create Managed Accounts via the API with `AutoManagementFlag: true` set on
each account, expecting rotation to be immediately active per the
per-account schedule also set at creation.

## What Happened

Account creation succeeded structurally (no field-validation errors), but
every account with `AutoManagementFlag: true` was rejected with:

```
400 Bad Request: "Managed System must have Auto-Management enabled to
auto-manage an account"
```

## Root Cause

`AutoManagementFlag` exists at two levels: the individual Managed Account,
and the parent Managed System (in this case, the single Directory-type
Managed System serving the whole environment). Setting the flag on an
*account* has no effect unless the parent *system* also has it enabled.
This is a one-time, environment-wide setting, not something a bulk-account
creation script should (or safely can) toggle as a side effect of creating
one account among many — but it also isn't obviously required reading
before the first bulk-creation attempt, since the API's own account-level
documentation doesn't foreground the system-level dependency.

Separately, a related but distinct problem: our accounts follow an
AD-group-based access model, not a locally-added-to-server model — the
large majority of service accounts get their actual system access by being
members of an AD security group that has been granted admin rights on one
or more servers, rather than by being added directly to any single
server's local Users. The console UI (and a related API endpoint,
`ManagedSystems/{systemID}/LinkedAccounts/{accountID}`) requires a
directory-managed account to be linked to a specific asset-type Managed
System before it's visible to requesters in the portal. For a
group-membership-based account, there is no single correct server to pick
— the group could grant access to any number of servers.

## What I Did to Fix It

- Enabled Auto-Management once, at the Directory Managed System level, as
  a one-time environment configuration step — confirmed first via a
  read-only `GET ManagedSystems/{id}` check before changing anything,
  since it's shared infrastructure affecting every account under that
  Directory.
- For the linking requirement, chose to link every group-membership-based
  account to the organization's domain controllers as a canonical,
  always-present anchor, rather than attempting to resolve "the" server
  for each account (which often doesn't exist as a single answer under
  this access model). This is explicitly a portal-visibility mechanism,
  not a representation of actual access — documented as such to avoid an
  auditor or reviewer mistakenly reading the link as "this account has
  admin rights on the domain controller."
- Confirmed the linking step is itself scriptable via the same API
  (`POST ManagedSystems/{systemID}/LinkedAccounts/{accountID}`, using the
  `ManagedAccountID` already returned from the account-creation call), so
  it can be folded into the same bulk-import pipeline rather than
  requiring a separate manual console pass per account.

## What I Would Do Differently

Check system-level prerequisites (Auto-Management enabled on the parent
Managed System, in this case) *before* the first bulk-creation attempt,
not after the first batch of otherwise-correct requests gets rejected.
For the linking question, I'd document the access model (group-membership
vs. direct local assignment) explicitly at the start of a migration
project, since it directly determines whether "link to the actual target
server" is even a well-formed instruction — for most of this environment,
it isn't, and a canonical anchor is a design decision, not a workaround.

## Key Takeaway

Two settings can share a name (`AutoManagementFlag`) at different levels
of a system's object hierarchy and require both to be true independently —
don't assume account-level configuration is sufficient just because the
field accepted the value without a validation error at creation time.
Separately: a "must link to a specific system" requirement doesn't
automatically map cleanly onto an AD-group-based access model — decide on
a deliberate, documented anchor strategy rather than trying to force a
one-to-one mapping that the environment doesn't actually have.
