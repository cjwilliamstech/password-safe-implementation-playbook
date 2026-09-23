# Lesson: A Source CSV Column Named `Username` Is Not the API's `AccountName` Field

## What I Was Trying to Do

Drive bulk Managed Account creation from a password-export CSV produced
by the legacy platform, mapping each row straight into the JSON body for
`POST ManagedSystems/{ManagedSystemID}/ManagedAccounts`. The intent was
a clean column-to-field pass-through: read a row, build the payload,
send it.

## What Happened

Accounts were created, but not the way the CSV implied. The source
export labeled its identity column `Username` (that's the header the
legacy tool writes), while the Password Safe `ManagedAccounts` create
payload expects the field `AccountName`. The two are not the same field,
they are not interchangeable, and the API does nothing to reconcile
them:

- When the payload was built by copying the CSV's `Username` value into
  a field literally called `Username`, the API accepted the call with a
  `200 OK` and simply ignored the unrecognized field — the created
  account had a blank/defaulted `AccountName` rather than the value from
  the export.
- Because creation "succeeded," nothing surfaced at import time. The
  mismatch only became visible later, when accounts couldn't be matched
  back to their source rows by name.

This bit us more than once, because the same class of column-name-vs-
field-name mismatch recurs across the different exports and the
different resources they feed.

## Root Cause

Two independent naming conventions that happen to describe "the account"
but use different words:

- The **source CSV** uses the legacy platform's column vocabulary
  (`Username`, and similar human-facing labels).
- The **Password Safe REST resource** uses its own schema vocabulary
  (`AccountName` on `ManagedAccounts`), which is **case-sensitive and
  resource-specific** — a field name that is valid on one resource may
  be absent on another.

Password Safe's API silently ignores fields it doesn't recognize on a
create payload (the same failure mode documented in Lesson 28 for
`FunctionalAccountID`), so a wrong field name is not rejected — it is
accepted and dropped. There is no server-side "did you mean
`AccountName`?" correction.

## What I Did to Fix It

Introduced an explicit column-name → API-field-name mapping step
between reading the CSV and building the payload, rather than assuming
the header equals the field:

```powershell
# Explicit map: source CSV column  ->  API field name
$fieldMap = @{
    'Username'    = 'AccountName'   # legacy export header -> ManagedAccounts field
    'Password'    = 'Password'
    # ...add each mapped column deliberately, don't pass through blindly
}

$body = @{}
foreach ($col in $fieldMap.Keys) {
    $body[$fieldMap[$col]] = $row.$col
}
```

Building the payload only from explicitly mapped, correctly-named fields
means an unmapped or misnamed column fails loudly at build time instead
of being silently dropped by the API at `200 OK`.

## What I Would Do Differently

Never assume a source export's column header is the API's field name,
even when they describe the same concept. Before building the first
payload, put one created record side by side with a `GET` on that
resource and confirm each value actually landed in the field you
intended — an account that was "created successfully" with a blank
`AccountName` is exactly the kind of failure that passes creation and
fails everything downstream.

## Key Takeaway

A column named `Username` in a source CSV and a field named
`AccountName` on the `ManagedAccounts` resource are two different names
for related-but-distinct things. Map source columns to API fields
explicitly and case-correctly; don't rely on pass-through, because
Password Safe accepts unrecognized fields with a `200 OK` and silently
ignores them rather than telling you the name was wrong.
