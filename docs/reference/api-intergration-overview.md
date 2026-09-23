# REST API Fundamentals — How the Password Safe Integration Actually Works

This document is a companion to the lessons-learned series and the
`Import-ManagedAccounts.ps1` script in this repo. It's written for anyone —
including future me — who needs a deeper mental model of *how* the
BeyondTrust Password Safe API actually works, not just which cmdlet to
paste. Everything below is genericized: no real hostnames, domains, or
account names appear anywhere in this file.

> **Reference:** BeyondTrust's official Password Safe API documentation
> lives at
> [https://docs.beyondtrust.com/bips/docs/password-safe-apis](https://docs.beyondtrust.com/bips/docs/password-safe-apis)
> (part of the broader Password Safe docs at
> [https://docs.beyondtrust.com/bips/docs/welcome-to-password-safe](https://docs.beyondtrust.com/bips/docs/welcome-to-password-safe)).
> This write-up is a field-notes companion built from real
> troubleshooting on this project — treat the vendor docs as the
> authoritative source for exact endpoint lists, field definitions, and
> any behavior not covered here.

## What Kind of API Is This?

Password Safe exposes a **REST API** (`/BeyondTrust/api/public/v3/...`).
It is not SOAP and not GraphQL:

- **Not SOAP** — no XML envelope, no WSDL contract, no `Action` header.
  Every request is a plain HTTP verb (`GET`, `POST`, `PUT`, `DELETE`)
  against a resource URL.
- **Not GraphQL** — there's no single endpoint you POST a query
  document to and no client-specified field selection. Each resource
  (`ManagedAccounts`, `ManagedSystems`, `Directories`,
  `FunctionalAccounts`, `Auth`, `Credentials`, etc.) has its own fixed
  URL and returns a fixed shape.
- **REST, resource-oriented** — the URL identifies *what* you're
  acting on, and the HTTP verb identifies *what you're doing to it*.
  `GET ManagedAccounts/{id}` reads one account. `POST
  ManagedSystems/{id}/ManagedAccounts` creates a new account under
  that managed system. `PUT Directories/{id}` updates a directory.

If you've worked with any modern SaaS API (GitHub, Azure, ServiceNow),
the shape will feel familiar. The learning curve in this project wasn't
REST itself — it was learning Password Safe's specific resource model,
which doesn't always match how the console UI presents the same data
(more on that below).

## Anatomy of a Call

Every call in the script boils down to the same four ingredients:

1. **A URL** — `https://[PS-APPLIANCE]/BeyondTrust/api/public/v3/<resource>`
2. **A verb** — `GET`/`POST`/`PUT`/`DELETE`, matching the action
3. **Headers** — content type and, after authentication, the session
   cookie/auth header
4. **A body** (for `POST`/`PUT` only) — a JSON object describing the
   thing you're creating or changing

In PowerShell, `Invoke-RestMethod` wraps all four:

```powershell
Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $jsonBody -ContentType "application/json"
```

`Invoke-RestMethod` automatically serializes a PowerShell hashtable to
JSON (via `ConvertTo-Json`) on the way out, and automatically
deserializes the JSON response back into a PowerShell object on the way
in. That auto-deserialization is convenient right up until something
goes wrong — see **Error Handling** below, because it's also the reason
the script needed a dedicated error-extraction helper.

## A Real Payload From This Project

Here's a genericized version of the actual JSON body the script sends
to create a managed account, from `POST
ManagedSystems/{ManagedSystemID}/ManagedAccounts`:

```json
{
  "AccountName": "[ACCOUNT-NAME]",
  "Password": "[SEEDED-PASSWORD]",
  "AutoManagementFlag": true,
  "ReleaseDuration": 120,
  "MaxReleaseDuration": 525600,
  "ChangeFrequencyType": "first",
  "ChangeFrequencyDays": 365,
  "ChangeTime": "08:00",
  "NextChangeDate": "2027-08-31"
}
```

A few things worth noticing, because they were all hard-won:

- **Field names are case-sensitive** and specific to this resource.
  `AccountName` here is not the same field as `Username` on other
  resources — and that distinction bit us more than once with the
  password-export CSVs (see Lesson 29 in the lessons-learned series).
- **`FunctionalAccountID` is deliberately absent.** Early drafts of the
  script included it in this body, and the API silently accepted the
  call (`200 OK`) without ever using the value — because
  `FunctionalAccountID` isn't a valid field on the `ManagedAccounts`
  create payload at all. It belongs on the `Directories` /
  `ManagedSystems` resource, not the account. This is fully written up
  in Lesson 28.
- **Dates and times are plain strings in specific formats**
  (`yyyy-MM-dd`, zero-padded `HH:mm`), not native JSON date types. The
  API does no format normalization on your behalf — if you send
  `8/31/2026` instead of `2026-08-31`, you get a rejection, not a
  silent correction. That's why the script has dedicated date/time
  parsers that normalize whatever format the source export happens to
  use before the payload is ever built.

## Authentication: a Credential Pair, Plus a Session

Password Safe's REST API doesn't use a bearer token model where you
mint a JWT and attach it to every call. Instead, it's closer to a
classic session model:

1. `POST Auth/SignAppIn` with an API key and a `runas` header
   (`PS-Auth key=[API-KEY]; runas=[DOMAIN.NET]\[ADMIN-USER];`). Note
   that `runas` needs the **FQDN domain format**
   (`[DOMAIN.NET]\[ADMIN-USER]`), not the NetBIOS short name
   (`[DOMAIN]\[ADMIN-USER]`) — using the short name is a reliable way
   to get a `401 Unauthorized` with no further explanation.
2. The appliance returns a session, tracked via cookie, that's valid
   for a limited idle window.
3. Every subsequent call in the session reuses that same
   authenticated context — no per-call token to attach.
4. `POST Auth/Signout` explicitly ends the session when you're done.

Two practical consequences that showed up repeatedly in this project:

- **Idle timeout is real.** A session left open too long between calls
  (e.g., while debugging a payload by hand) will start returning `401`
  again. The fix isn't a code change — it's re-running the
  `Auth/SignAppIn` call to get a fresh session.
- **The API key + `runas` account is not the same thing as the account
  actually performing rotations on target systems.** The API key
  authenticates *you* to Password Safe. The *Functional Account*
  configured on the Directory/Managed System is what Password Safe
  itself uses to reach out and change a password on the target host.
  Conflating these two was the root cause behind Lesson 28.

## Resource Modeling Doesn't Always Match Mental Models

The single biggest adjustment in this project was realizing that
Password Safe's REST resources don't always mirror how the console UI
groups the same data visually. A few examples:

- The console shows a managed account's "Functional Account" on a tab
  that visually sits right next to account details — but
  `FunctionalAccountID` isn't a field on the `ManagedAccounts`
  resource at all. It lives on `Directories` and `ManagedSystems`.
  Sending it on the account-creation call doesn't error — it's just
  silently ignored, because the API schema for that resource has no
  such field to accept it into.
- `ManagedAccounts`, `ManagedSystems`, `Directories`, and
  `FunctionalAccounts` are four distinct resources with
  non-overlapping schemas, even though the console UI can make them
  feel like one continuous record. Each has its own `GET`/`POST`/`PUT`
  endpoint family, and a field that exists on one will 400 (or be
  silently ignored) on another.
- Confirmed the hard way: `PUT Directories/{id}` will accept a
  `FunctionalAccountID` correction and return `200 OK` with the new
  value echoed back in the response — but on a subsequent `GET`, the
  old value is still there. Only the console UI's "Update Functional
  Account" action on the Managed Systems → Functional Account tab
  actually persists the change for that field. This is documented in
  full in Lesson 28, including the workaround.
- The same `PUT Directories/{id}` call also required `ForestName` and
  `NetBiosName` to be included in the request body even though a prior
  `GET` on that same directory returned them as blank/null. The API
  validates what you send on write more strictly than what it's
  willing to return on read.

**Takeaway:** never assume a field visible in the console UI maps
1:1 to a field on the REST resource you're calling. Always confirm
against an actual `GET` response for that specific resource before
building a `POST`/`PUT` payload.

## Error Handling: the Status Code Is Not the Error Message

This was the most repeated friction point in the whole project.
`Invoke-RestMethod` in Windows PowerShell 5.1 throws a
`WebException`/`HttpResponseException` on any non-2xx status — but by
default it does **not** surface the response body, which is exactly
where Password Safe puts the actually-useful error detail. Without
extra handling, a real API rejection collapses down to something like:

```
Invoke-RestMethod : The remote server returned an error: (400) Bad Request.
```

That's a category, not a reason. The real reason — e.g. `"Managed
System must have Auto-Management enabled to auto-manage an account"`
or `"Access is denied"` — is in the JSON body of the error response,
which PowerShell 5.1 discards unless you go get it yourself.

The fix used in this script is a small helper
(`Get-DetailedErrorMessage`) that, on catching the exception, reads the
raw response stream directly off the underlying
`HttpWebResponse`/`WebException` and parses the JSON body out of it,
rather than relying on whatever `Invoke-RestMethod` chose to bubble up.
Every "Failed row" line in the script's report CSV comes from this
helper — without it, troubleshooting a bulk import of hundreds of rows
would have meant guessing from status codes alone.

**Rule of thumb for any REST integration:** the HTTP status code tells
you *the shape* of the failure (client error vs. server error vs. auth
failure). The response body tells you *the actual reason*. Never build
error handling that discards the body.

## Versioning

All calls in this project target `api/public/v3`. The version is part
of the URL path itself, not a header or query parameter — so a future
`v4` (if BeyondTrust ships one) would be a distinct, parallel path
rather than something toggled on the same endpoint. That also means
nothing about this integration will silently start behaving
differently underneath us due to a server-side version bump; a break
would require us to deliberately point at a new path.

## Summary

| Concept | How it works here |
|---|---|
| API style | REST, resource-oriented (not SOAP, not GraphQL) |
| Payload format | JSON, plain strings for dates/times (no native date type) |
| Auth model | API key + `runas` → session via `Auth/SignAppIn`, not a bearer token |
| Domain format | FQDN required in `runas` (`[DOMAIN.NET]\[USER]`), NetBIOS fails silently as 401 |
| Session lifetime | Idle timeout exists; re-auth on stale-session 401s |
| Resource boundaries | `ManagedAccounts` / `ManagedSystems` / `Directories` / `FunctionalAccounts` are separate schemas — a field valid on one is invalid or silently ignored on another |
| Console vs. API | Not always 1:1 — some fields (e.g. Directory-level `FunctionalAccountID`) can only be reliably persisted through the console UI, not a direct `PUT` |
| Error detail | Lives in the response body's JSON, not the HTTP status code — PowerShell 5.1 hides it unless you read the response stream yourself |
| Versioning | Embedded in the URL path (`v3`), not a header |

Related reading in this repo: Lesson 24 (the NetBIOS-vs-FQDN `runas`
format that produces a silent `401` from `Auth/SignAppIn`), Lesson 26
(why the API's response body — not the HTTP status code — carries the
real reason a `4xx` failed), Lesson 28 (functional-account routing and
the `FunctionalAccountID` API-vs-console discrepancy, full incident
writeup).

## Further Reading

- BeyondTrust Password Safe API documentation:
  [https://docs.beyondtrust.com/bips/docs/password-safe-apis](https://docs.beyondtrust.com/bips/docs/password-safe-apis)
- Password Safe product documentation home:
  [https://docs.beyondtrust.com/bips/docs/welcome-to-password-safe](https://docs.beyondtrust.com/bips/docs/welcome-to-password-safe)