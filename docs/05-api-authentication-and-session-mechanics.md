# Secrets Safe Public API — Authentication & Session Mechanics

Distilled from a working proof-of-concept: authenticating to the Password Safe Public
API (v3) with Windows PowerShell 5.1, establishing a session, enumerating Secrets Safe
Safes/folders, and creating a credential secret with the correct ownership schema.
This is the mechanical layer underneath
[`scripts/Import-SecretsSafeCredentials.ps1`](../scripts/Import-SecretsSafeCredentials.ps1)
— read this if you're extending that script or building something new against the same
API surface.

## Request flow

1. Configure an **API Key Policy** registration in BeyondInsight.
2. Grant the appropriate BeyondInsight **group** access to that API registration.
3. Ensure the `runas` user is a member of that group.
4. Configure approved authentication rules (e.g. an explicit source-IP restriction).
5. Build a `PS-Auth` Authorization header containing the API key and `runas` user.
6. `POST Auth/SignAppIn` and capture the returned session cookies in a
   `WebRequestSession` object.
7. Reuse that same session object for every subsequent call.
8. Enumerate Safes/folders to obtain the GUIDs you need to target.
9. Create credential secrets using the required ownership schema (see below).
10. `POST Auth/SignOut` in a `finally` block — always, even on error paths.

## The most important gotcha: registration ≠ authorization

**Having an active API Key Policy registration is not sufficient on its own.** The
BeyondInsight group containing your `runas` user must also have that specific API
registration explicitly assigned/selected in User Management. Without that
assignment, every sign-in attempt returns:

```
HTTP 401
Failed to authenticate due to one or more authentication rules.
```

This looks identical to a bad/expired key, a wrong `runas` value, or an IP
restriction problem — it is none of those. Diagnostic order that actually narrows it
down:

1. Confirm the endpoint is reachable over HTTPS at all.
2. Confirm the API registration is **active**.
3. Confirm the registration is **assigned to the correct group** in User Management —
   this is the step that's easy to miss, since it's a separate screen from where the
   registration itself is created.
4. Confirm the `runas` user is actually a member of that group.
5. Only then start inspecting IP/PSRUN/`X-Forwarded-For` authentication rules and
   Authorization-header formatting.

## Owner schema for created secrets

Creating a secret with an `Owners` collection has two easy-to-miss requirements:

- The request must target **API version 3.1** (append `?version=3.1` to the
  create-secret endpoint).
- Each object inside `Owners` needs a **`UserId`** (or `GroupId`) property — a generic
  `Id` field is silently rejected with `HTTP 400: Invalid OwnerType`.

```json
// Rejected
{ "Owners": [ { "Id": 1234 } ] }

// Accepted
{
  "OwnerType": "User",
  "Owners": [ { "UserId": 1234 } ]
}
```

JSON property *order* doesn't matter here (PowerShell's `ConvertTo-Json` won't
preserve hashtable insertion order anyway) — only property names, nesting, and values
are evaluated by the API.

## Working PowerShell pattern (sanitized)

Sign-in → folder discovery → create one credential → sign-out, with the correct owner
schema. Populate the placeholders only in a secured local copy — never commit real
values.

```powershell
$ErrorActionPreference = 'Stop'

$BaseUri     = 'https://<password-safe-host>/BeyondTrust/api/public/v3'
$ApiKey      = '<CURRENT_API_KEY>'          # never hardcode in a committed script
$RunAs       = '<DOMAIN\username>'
$FolderId    = '<TARGET_FOLDER_GUID>'
$OwnerUserId = 1234

$headers = @{
    Accept        = 'application/json'
    Authorization = "PS-Auth key=$ApiKey; runas=$RunAs;"
}

$Session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

try {
    $signIn = Invoke-RestMethod -Uri "$BaseUri/Auth/SignAppIn" -Method POST `
        -Headers $headers -WebSession $Session
    Write-Host "Signed in as $($signIn.UserName)"

    $folders = Invoke-RestMethod `
        -Uri "$BaseUri/secrets-safe/folders?IncludeSubfolders=true&Limit=1000" `
        -Method GET -WebSession $Session
    $folders | Select-Object Id, Name, ParentId | Format-Table -AutoSize

    $body = @{
        Username    = 'test-import-user'
        Password    = '<TEMPORARY_TEST_PASSWORD>'
        Title       = 'API Import Test'
        Description = 'Created via API test'
        OwnerType   = 'User'
        Owners      = @( @{ UserId = $OwnerUserId } )
    } | ConvertTo-Json -Depth 5

    $createdSecret = Invoke-RestMethod `
        -Uri "$BaseUri/secrets-safe/folders/$FolderId/secrets?version=3.1" `
        -Method POST -ContentType 'application/json' -Body $body -WebSession $Session

    $createdSecret | Select-Object Id, Title, Username, FolderPath
}
catch {
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        Write-Error $reader.ReadToEnd()
    }
    else {
        Write-Error $_.Exception.Message
    }
}
finally {
    try {
        Invoke-RestMethod -Uri "$BaseUri/Auth/SignOut" -Method POST -WebSession $Session | Out-Null
    }
    catch {
        Write-Warning "SignOut failed: $($_.Exception.Message)"
    }
    $ApiKey = $null; $headers = $null; $Session = $null; $body = $null
}
```

## Other things that will trip you up

| Symptom | Cause | Fix |
|---|---|---|
| `ps-cli` not recognized | Vendor CLI/Python not installed | Use native PowerShell `Invoke-RestMethod` instead — no extra dependency, matches the API reference examples directly |
| Direct `GET` returns 401 before you've signed in | No session established yet | Always `POST Auth/SignAppIn` first and reuse the resulting session |
| "response content cannot be parsed... Internet Explorer engine is not available" | `Invoke-WebRequest` on PS 5.1 defaults to a legacy IE-based parser | Use `Invoke-RestMethod`, or add `-UseBasicParsing` to `Invoke-WebRequest` |
| `Invalid URI: The hostname could not be parsed` | A base URL variable was empty/unset in the session | Explicitly define and echo the variable before building endpoint URLs |
| `Incomplete string token` / malformed URI | Rich-text hyperlink or HTML anchor markup pasted into the console instead of a plain URL | Paste only a plain quoted string; watch for smart quotes copied from documentation pages |

## Considered alternative: native CSV upload endpoint

The API also documents a native bulk endpoint:

```
POST /secrets-safe/folders/{folderId}/upload
```

It accepts `multipart/form-data` and returns `totalNumber`, `successfulImport`, and
line-level errors. Worth evaluating against your actual requirements (ownership
assignment per row, safe/folder routing logic, validation, audit trail) before
choosing it over row-by-row creation — the row-by-row approach used in
[`scripts/Import-SecretsSafeCredentials.ps1`](../scripts/Import-SecretsSafeCredentials.ps1)
gives more control over per-row owner assignment and error handling at the cost of
more requests.

## Security handling

- Never print `$headers`, `$headers.Authorization`, or a `$Session` object during any
  troubleshooting session that's recorded, screen-shared, or pasted into a chat/ticket
  — all three can carry the Authorization header or an active session token.
- Treat any API key that appeared in a terminal, screenshot, transcript, or shell
  history as exposed — rotate it and restore any authentication rules (e.g. an
  explicit source-IP restriction) that were relaxed for testing, regardless of
  confidence that "nobody actually saw it."
- Use a dedicated, least-privilege API registration for migration/import work, and
  disable or restrict it once the work is done rather than leaving it active
  indefinitely.
