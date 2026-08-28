# Lesson: A Silent 401 from `Auth/SignAppIn` Traced to NetBIOS vs. FQDN in the `runas` Claim

## What I Was Trying to Do

Move an interactively-tested API authentication pattern into a reusable
script. The manual version — typed directly into a PowerShell session —
authenticated successfully on the first try:

```
Authorization = "PS-Auth key=<key>; runas=[DOMAIN.NET]\[ADMIN-USER];"
```

The script version constructed the same header programmatically, expecting
identical behavior.

## What Happened

The script's version of the same call failed with a generic
`(401) Unauthorized` from `Auth/SignAppIn` — no other detail, because
Windows PowerShell 5.1's `Invoke-RestMethod` doesn't surface the API's own
response body for HTTP error statuses by default, only a generic
`.NET` exception message (see the related lesson on surfacing detailed API
errors).

## Root Cause

The script built the `runas` value dynamically:

```powershell
$runAsUser = "$env:USERDOMAIN\$env:USERNAME"
```

`$env:USERDOMAIN` returns the **NetBIOS** short domain name (e.g.
`[NETBIOS-SHORT-NAME]`), not the fully-qualified domain name
(`[DOMAIN.NET]`) that had been hardcoded in the working manual test. The
API's `runas` matching apparently expects the FQDN form — consistent with
how every Functional Account and Directory registration in this
environment is stored using the FQDN, not the NetBIOS name. A
NetBIOS-vs-FQDN mismatch produced a 401 with no further explanation.

## What I Did to Fix It

Switched to `$env:USERDNSDOMAIN`, which returns the FQDN, with a fallback
to `$env:USERDOMAIN` only if the FQDN variable is empty (e.g. a
non-domain-joined session):

```powershell
$domain = if ($env:USERDNSDOMAIN) { $env:USERDNSDOMAIN } else { $env:USERDOMAIN }
$RunAsUser = "$domain\$env:USERNAME"
```

Also added an explicit `Accept: application/json` header to exactly match
the known-working manual pattern, and made `RunAsUser` an overridable
script parameter rather than a hidden derived value, so a future
NetBIOS/FQDN environment quirk doesn't have to be rediscovered the same
way.

## What I Would Do Differently

When porting a manually-verified working call into a script, diff every
constructed value against the literal working version *before* running the
script — not after getting an opaque error. `$env:USERDOMAIN` looking
"close enough" to a hardcoded FQDN is exactly the kind of near-miss that's
invisible until it isn't.

## Key Takeaway

`$env:USERDOMAIN` is not the same as your Active Directory FQDN. If an API
integration's `runas`/identity claim format matters, use
`$env:USERDNSDOMAIN` (or an explicit, documented value) — never assume the
short domain name and the FQDN are interchangeable just because they refer
to the same domain.
