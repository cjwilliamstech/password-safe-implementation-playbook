# Lesson: Every 4xx Error Looked Identical Until the API's Own Response Body Was Extracted

## What I Was Trying to Do

Diagnose why a bulk account-creation script was failing on specific
accounts, using the error detail captured in the script's own report.

## What Happened

Two completely different underlying problems — an authentication failure
and, later, a business-rule rejection ("Managed System must have
Auto-Management enabled to auto-manage an account") — both surfaced
identically in the script's error handling:

```
The remote server returned an error: (401) Unauthorized.
The remote server returned an error: (400) Bad Request.
```

No further detail. Every 4xx error looked the same regardless of cause,
which meant every failure required a fresh round of speculation rather
than reading an actual explanation.

## Root Cause

In Windows PowerShell 5.1, `Invoke-RestMethod` throws a generic
`System.Net.WebException` for HTTP error status codes. The exception's
`.Message` property only contains the status line — it does **not**
include the response body, even when the API returned a perfectly
descriptive JSON error message. The actual explanation from the API (e.g.
`"Managed System must have Auto-Management enabled to auto-manage an
account"`) was present on the wire and simply never read by the script's
`catch` blocks, which only logged `$_.Exception.Message`.

## What I Did to Fix It

Added a helper that reads the response body directly off the exception's
underlying `HttpWebResponse` when present, and appends it to the logged
error:

```powershell
function Get-DetailedErrorMessage {
    param($ErrorRecord)
    $msg = $ErrorRecord.Exception.Message
    try {
        $resp = $ErrorRecord.Exception.Response
        if ($resp) {
            $stream = $resp.GetResponseStream()
            $stream.Position = 0
            $reader = New-Object System.IO.StreamReader($stream)
            $body = $reader.ReadToEnd()
            if ($body) { $msg = "$msg | API response body: $body" }
        }
    } catch { }
    return $msg
}
```

Wired this into every `catch` block that handles an API call, replacing
plain `$_.Exception.Message` usage throughout.

## What I Would Do Differently

Build this helper on day one of any PowerShell-5.1-based API integration
script, before writing the first real API call — not after the second
confusing, identical-looking error in a row. The five minutes it takes to
add costs far less than one round of "which of these two completely
different problems is this generic message actually describing?"

## Key Takeaway

A generic HTTP status code is not the same as an error message. If the API
you're calling returns descriptive error bodies (most REST APIs do), make
sure your error handling actually reads them — otherwise you're throwing
away the most useful diagnostic information available, every single time
something fails.
