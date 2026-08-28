<#
.SYNOPSIS
    Bulk-creates Password Safe Managed Accounts, optionally seeding the current
    password, and configures the annual/off-hours rotation schedule in one pass.

.DESCRIPTION
    This script reads a CSV of account metadata (NO passwords in the CSV) and,
    for each row, calls POST ManagedSystems/{systemID}/ManagedAccounts to:
      1. Create the Managed Account
      2. Optionally seed the account's current password (so Password Safe's
         record matches AD/the target system on day one, instead of drifting
         until someone runs Edit Managed Account -> Set Password)
      3. Enable AutoManagementFlag and set the rotation schedule
         (ChangeFrequencyType/ChangeFrequencyDays/ChangeTime) so the account
         is under management immediately.

    Why this exists: Smart Rule + Directory Query discovery (the OU-move
    approach used for a multi-entity Priority 1 migration) creates the
    Managed Account shell but does NOT know the account's current password.
    That gap has to be closed manually per account afterward. This script is
    the alternative path for cases where you already know the ManagedSystemID
    and want to seed the password and rotation schedule at creation time,
    skipping the manual step.

    SECURITY / SAME-DAY EXPORT DESIGN:
    - The input CSV (-CsvPath) contains only non-secret metadata (account
      name, SAM, UPN, domain, target ManagedSystemID). It never contains a
      password column, and this script never writes a password to disk,
      to the report CSV, or to the console/transcript.
    - Current passwords come from a SEPARATE file (-SecureExportPath),
      expected to be exported fresh from your encrypted credential store
      on the same day this script runs, with columns AccountName,Password.
      This script:
        1. Loads that file into memory ONCE at the start, converting every
           password to a SecureString immediately and discarding the
           plaintext CSV rows from the variable that held them.
        2. Looks up each account's password from that in-memory table as
           needed during the loop — the export file itself is only read
           once, not re-opened per account.
        3. With -PurgeExportAfterRun, best-effort overwrites and deletes
           the export file the moment the script finishes (success or
           failure) — see Remove-SecureExportFile. This is best-effort:
           on SSDs or journaling filesystems, overwrite-before-delete does
           not guarantee the original bytes are unrecoverable at the
           hardware level. The real control is your encrypted folder's
           access policy and how briefly the plaintext export exists
           outside it — treat -PurgeExportAfterRun as a courtesy cleanup,
           not a substitute for that.
    - For accounts where SeedPassword=true, after a successful create the
      script calls POST ManagedAccounts/{id}/Credentials/Test to confirm
      the seeded password is actually valid against the live system —
      without changing it. Because the export could be stale relative to
      the live password (e.g., a manual change since export, or drift not
      yet reflected in the encrypted store), this test converts a silent
      future checkout failure into an immediate, visible report line
      instead. Accounts that fail this test still exist in Password Safe
      and remain under AutoManagementFlag; they simply won't have a
      confirmed-accurate password until the first scheduled rotation.
    - The API key itself is read from the PWSAFE_API_KEY machine-scope
      environment variable (matching the pattern used in
      Import-SecretsSafeCredentials.ps1), or entered via a WinForms secure
      prompt at runtime if not present.
    - Run with -WhatIf first. Nothing is created against the appliance
      until you drop -WhatIf. Note: -WhatIf still loads and holds the
      export in memory (so you can validate lookups resolve correctly)
      but never calls Credentials/Test, since no account was actually
      created to test against.

.PARAMETER CsvPath
    Path to input CSV. Expected columns (header row required):
    AccountName, SAMAccountName, UserPrincipalName, DomainName,
    ManagedSystemID, SeedPassword (true/false), ChangeFrequencyDays,
    ChangeTime, NextChangeDate, Notes

    ChangeTime and NextChangeDate are PER-ACCOUNT because rotation windows
    are dictated by individual system/application impact tolerance and
    account owner availability — there is no single after-hours window
    that fits every account in a large batch. ChangeFrequencyDays is also per-row in
    case any account needs a non-annual cadence, but will typically be
    365 for all rows. Any row that leaves these columns blank falls back
    to the -DefaultChangeFrequencyDays / -DefaultChangeTime script
    parameters below — but blank should be the exception, not the norm,
    given the business constraint driving this design.

.PARAMETER ApiBaseUrl
    Base URL of the Password Safe public API, e.g.
    https://[PS-APPLIANCE]/BeyondTrust/api/public/v3

.PARAMETER FunctionalAccountID
    ID of the functional account (e.g. s-PWS-AD-Func) used for rotation.
    Must match PlatformID of the target accounts.

.PARAMETER DefaultChangeFrequencyDays
    Fallback rotation interval in days, used only when a row's
    ChangeFrequencyDays column is blank. Default 365.

.PARAMETER DefaultChangeTime
    Fallback UTC time (HH:mm), used only when a row's ChangeTime column
    is blank. Default 23:30. Remember appliance/API time is UTC — the
    per-row ChangeTime values in the CSV must already be converted from
    Hawaii local time to UTC before they go in the file.

.PARAMETER OutputPath
    Directory for the report CSV. Default C:\PWS-Reports

.PARAMETER SecureExportPath
    Path to the same-day export of current passwords, columns:
    AccountName,Password (plaintext in the file itself — that's why this
    must be a fresh, narrow-window export from your encrypted folder, not
    a file that lingers). Required only if any row has SeedPassword=true.
    Matching against -CsvPath's AccountName is normalized (case-insensitive,
    strips a DOMAIN\ prefix if present) — verify your export's naming
    convention lines up before running at scale; mismatches show up as
    "Failed" rows with a clear lookup error, not silent skips.

.PARAMETER PurgeExportAfterRun
    Switch. When set, best-effort overwrites and deletes the file at
    -SecureExportPath as soon as the script finishes (success, failure,
    or Ctrl+C — handled in a finally block). See the SECURITY note above
    on the limits of this guarantee.

.PARAMETER ServiceNowTask
    ServiceNow task number to stamp into the report for traceability.

.PARAMETER WhatIf
    Dry-run. Builds and logs every request that WOULD be sent, but makes
    no POST calls. Always run this first on a new CSV.

.EXAMPLE
    .\Import-ManagedAccounts.ps1 -CsvPath C:\Temp\Wave1-Accounts.csv `
        -ApiBaseUrl https://[PS-APPLIANCE]/BeyondTrust/api/public/v3 `
        -FunctionalAccountID [FUNCTIONAL-ACCOUNT-ID] -SecureExportPath [PATH-TO]\wave1-passwords.csv `
        -PurgeExportAfterRun -ServiceNowTask TASK0012345 -WhatIf

.NOTES
    Author:     C.Williams
    Platform:   BeyondTrust Password Safe On-Premises v26.2
    Requires:   PowerShell 5.1, network reachability to [PS-APPLIANCE] API endpoint

    OPERATIONAL SEQUENCE THIS SCRIPT ASSUMES:
    1. Export current passwords from the encrypted folder to
       -SecureExportPath, same day, immediately before running this script.
    2. Run this script with -WhatIf first against the wave's CSV.
    3. Run for real with -PurgeExportAfterRun so the plaintext export is
       removed the moment the script completes.
    4. Confirm nothing failed the Credentials/Test check in the report
       before considering the wave done.

    REMAINING ITEM TO CONFIRM BEFORE PRODUCTION USE:
    - Resolve existing-account skip logic if re-running against a partial
      import (see the TODO near the main loop)
#>

function Start-PWSManagedAccountImport {
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$CsvPath,

    [Parameter(Mandatory = $true)]
    [string]$ApiBaseUrl,

    [Parameter(Mandatory = $true)]
    [int]$FunctionalAccountID,

    [int]$DefaultChangeFrequencyDays = 365,

    [string]$DefaultChangeTime = "23:30",

    [string]$OutputPath = "C:\PWS-Reports",

    [string]$SecureExportPath,

    [switch]$PurgeExportAfterRun,

    [string]$ServiceNowTask = "",

    [int]$DefaultReleaseDuration = 120,   # minutes (2 hours)
    [int]$MaxReleaseDuration = 480        # minutes (8 hours)
)

# ---------------------------------------------------------------------------
# 1. API key acquisition (matches Import-SecretsSafeCredentials.ps1 pattern)
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# 0. Error detail helper. Invoke-RestMethod in Windows PowerShell 5.1 only
#    surfaces a generic ".NET exception message (e.g. "(400) Bad Request")
#    for HTTP error responses — it does NOT show the API's own response
#    body, which is where BeyondTrust actually explains WHY (invalid field,
#    missing required value, platform mismatch, etc.). Without this, every
#    4xx error looks identical and undiagnosable. This pulls the real body
#    out of the underlying HttpWebResponse when present.
# ---------------------------------------------------------------------------
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
            if ($body) {
                $msg = "$msg | API response body: $body"
            }
        }
    } catch {
        # If the response stream can't be read (already consumed, etc.),
        # fall back to the generic message rather than failing the catch itself.
    }
    return $msg
}

function Get-ApiKeySecure {
    # Machine env var lookup intentionally bypassed for now — always prompt,
    # so there's no ambiguity about which key value is actually being used.
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form -Property @{
        Text = "Password Safe API Key"
        Width = 420
        Height = 150
        StartPosition = "CenterScreen"
        TopMost = $true
    }
    $label = New-Object System.Windows.Forms.Label -Property @{
        Text = "Enter Password Safe API key:"; Left = 10; Top = 5; Width = 380
    }
    $textBox = New-Object System.Windows.Forms.TextBox -Property @{
        Left = 10; Top = 25; Width = 380; UseSystemPasswordChar = $true
    }
    $okButton = New-Object System.Windows.Forms.Button -Property @{
        Text = "OK"; Left = 150; Top = 65; DialogResult = "OK"
    }
    $form.Controls.AddRange(@($label, $textBox, $okButton))
    $form.AcceptButton = $okButton
    $form.Add_Shown({ $form.Activate(); $textBox.Focus() })
    [void]$form.ShowDialog()

    if (-not $textBox.Text) {
        throw "No API key entered — stopping."
    }

    return (ConvertTo-SecureString $textBox.Text -AsPlainText -Force)
}

# ---------------------------------------------------------------------------
# 2. Same-day password export handling.
#    Loaded ONCE into a SecureString dictionary; the plaintext CSV rows are
#    discarded from the variable immediately after conversion. Lookups
#    during the main loop hit this in-memory table, not the file again.
# ---------------------------------------------------------------------------
function ConvertTo-NormalizedAccountKey {
    param([string]$Name)
    # Strip a DOMAIN\ prefix if present, uppercase for case-insensitive match.
    $bare = $Name -replace '^.*\\', ''
    return $bare.Trim().ToUpperInvariant()
}

function Import-PasswordExportSecure {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path $Path)) {
        throw "SecureExportPath '$Path' not found. Export must exist and be fresh before running with SeedPassword=true rows."
    }

    $table = [System.Collections.Generic.Dictionary[string, Security.SecureString]]::new()

    # Import-Csv streams row objects; each row's plaintext Password value is
    # converted and discarded as we go rather than retained in a bulk array.
    Import-Csv -Path $Path | ForEach-Object {
        $key = ConvertTo-NormalizedAccountKey $_.AccountName
        if ($table.ContainsKey($key)) {
            Write-Warning "Duplicate account name in export after normalization: $key — keeping first occurrence."
            return
        }
        $secure = ConvertTo-SecureString $_.Password -AsPlainText -Force
        $table[$key] = $secure
        # Best-effort: null the row's plaintext property reference.
        $_.Password = $null
    }

    Write-Host "Loaded $($table.Count) password entries from export."
    return $table
}

function Get-CurrentPasswordSecureString {
    param(
        [Parameter(Mandatory = $true)][string]$AccountName,
        [Parameter(Mandatory = $true)][System.Collections.Generic.Dictionary[string, Security.SecureString]]$PasswordTable
    )

    $key = ConvertTo-NormalizedAccountKey $AccountName
    if (-not $PasswordTable.ContainsKey($key)) {
        throw "No entry found in SecureExportPath for account '$AccountName' (normalized key '$key'). Check naming convention/domain prefix mismatch between the export and the CSV."
    }
    return $PasswordTable[$key]
}

function Remove-SecureExportFile {
    param([string]$Path)

    if (-not $Path -or -not (Test-Path $Path)) { return }

    try {
        # Best-effort overwrite before delete. Not a guarantee on SSD/journaling
        # filesystems — see SECURITY note in header. The real control is how
        # briefly this file exists outside the encrypted folder.
        $len = (Get-Item $Path).Length
        $randomBytes = New-Object byte[] $len
        [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($randomBytes)
        [System.IO.File]::WriteAllBytes($Path, $randomBytes)
        Remove-Item -Path $Path -Force
        Write-Host "Purged secure export file: $Path"
    } catch {
        Write-Warning "Failed to purge '$Path' — remove it manually now. Error: $($_.Exception.Message)"
    }
}

function ConvertFrom-SecureStringPlain {
    param([Security.SecureString]$SecureString)
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

# ---------------------------------------------------------------------------
# 3. Auth (SignAppIn) — runas user must belong to a group with the API
#    registration assigned (see your Key Learning re: 401 root cause).
# ---------------------------------------------------------------------------
function Connect-PasswordSafeApi {
    param(
        [string]$BaseUrl,
        [Security.SecureString]$ApiKeySecure,
        [string]$RunAsUser  # optional override; defaults to FQDN\username below
    )

    $apiKey = ConvertFrom-SecureStringPlain $ApiKeySecure

    if (-not $RunAsUser) {
        # $env:USERDOMAIN is the NetBIOS short name (e.g. [NETBIOS-SHORT-NAME]) and
        # does NOT match the FQDN format your API registration expects
        # (confirmed working pattern: [DOMAIN.NET]\[ADMIN-USER]).
        # $env:USERDNSDOMAIN gives the FQDN. Fall back to USERDOMAIN only if
        # USERDNSDOMAIN is somehow blank (e.g. non-domain-joined session).
        $domain = if ($env:USERDNSDOMAIN) { $env:USERDNSDOMAIN } else { $env:USERDOMAIN }
        $RunAsUser = "$domain\$env:USERNAME"
    }

    $headers = @{
        Accept        = "application/json"
        Authorization = "PS-Auth key=$apiKey; runas=$RunAsUser;"
    }

    $session = $null
    Invoke-RestMethod -Uri "$BaseUrl/Auth/SignAppIn" -Method POST `
        -Headers $headers -SessionVariable session -ErrorAction Stop | Out-Null

    # Zero out the plaintext key ASAP
    $apiKey = $null
    [GC]::Collect()

    return @{ Session = $session; Headers = $headers }
}

function Disconnect-PasswordSafeApi {
    param($BaseUrl, $Session, $Headers)
    try {
        Invoke-RestMethod -Uri "$BaseUrl/Auth/Signout" -Method POST `
            -WebSession $Session -Headers $Headers -ErrorAction SilentlyContinue | Out-Null
    } catch { }
}

# ---------------------------------------------------------------------------
# 4. Skip logic — don't recreate an account that already exists on the
#    target Managed System. TODO: confirm exact match semantics wanted
#    (AccountName only, vs AccountName+SAMAccountName) before production use.
# ---------------------------------------------------------------------------
function Test-ManagedAccountExists {
    param($BaseUrl, $Session, $Headers, [int]$ManagedSystemID, [string]$AccountName)

    try {
        $existing = Invoke-RestMethod `
            -Uri "$BaseUrl/ManagedSystems/$ManagedSystemID/ManagedAccounts?name=$AccountName" `
            -Method GET -WebSession $Session -Headers $Headers -ErrorAction Stop
        return [bool]$existing
    } catch {
        # 404 = not found = does not exist yet
        return $false
    }
}

# ---------------------------------------------------------------------------
# 5. Main
# ---------------------------------------------------------------------------
$rows = Import-Csv -Path $CsvPath
$report = [System.Collections.Generic.List[object]]::new()

$needsSeeding = ($rows | Where-Object { [bool]::Parse($_.SeedPassword) }).Count -gt 0
$passwordTable = $null
if ($needsSeeding) {
    if (-not $SecureExportPath) {
        throw "One or more rows have SeedPassword=true but -SecureExportPath was not provided."
    }
    $passwordTable = Import-PasswordExportSecure -Path $SecureExportPath
}

$apiKeySecure = Get-ApiKeySecure
try {
    $conn = Connect-PasswordSafeApi -BaseUrl $ApiBaseUrl -ApiKeySecure $apiKeySecure
} catch {
    Write-Error "Authentication to Password Safe API failed — stopping before touching any accounts. $(Get-DetailedErrorMessage $_)"
    if ($passwordTable) { $passwordTable.Clear() }
    return
}
if (-not $conn -or -not $conn.Session) {
    Write-Error "Authentication did not return a valid session — stopping before touching any accounts."
    if ($passwordTable) { $passwordTable.Clear() }
    return
}

try {
    foreach ($row in $rows) {

        $accountName = $row.AccountName
        $systemId    = [int]$row.ManagedSystemID
        $seedPw      = [bool]::Parse($row.SeedPassword)

        $resultRow = [ordered]@{
            AccountName        = $accountName
            ManagedSystemID    = $systemId
            SeededPassword     = $seedPw
            PasswordValidated  = ""
            ChangeFrequencyDays = $(if ($row.ChangeFrequencyDays) { $row.ChangeFrequencyDays } else { $DefaultChangeFrequencyDays })
            ChangeTimeUTC      = $(if ($row.ChangeTime) { $row.ChangeTime } else { $DefaultChangeTime })
            NextChangeDate     = $row.NextChangeDate  # raw value pending normalization below; updated after parsing
            Status             = ""
            Detail             = ""
            ServiceNowTask     = $ServiceNowTask
            Timestamp          = (Get-Date -Format "s")
        }

        try {
            if (Test-ManagedAccountExists -BaseUrl $ApiBaseUrl -Session $conn.Session `
                    -Headers $conn.Headers -ManagedSystemID $systemId -AccountName $accountName) {
                $resultRow.Status = "Skipped"
                $resultRow.Detail = "Account already exists on ManagedSystemID $systemId"
                $report.Add([pscustomobject]$resultRow)
                continue
            }

            # --- Per-account rotation schedule -------------------------------
            # Each account's ChangeTime/NextChangeDate reflects that specific
            # system's after-hours window and owner availability — these are
            # NOT uniform across the batch. Fall back to script defaults only
            # when a row genuinely leaves the column blank.

            $rowChangeFreqDays = if ($row.ChangeFrequencyDays) { [int]$row.ChangeFrequencyDays } else { $DefaultChangeFrequencyDays }
            $rowChangeTime     = if ($row.ChangeTime)          { $row.ChangeTime }               else { $DefaultChangeTime }
            $rowNextChangeDateRaw = $row.NextChangeDate  # optional; blank = let Password Safe pick the first occurrence

            if ($rowChangeTime -notmatch '^\d{2}:\d{2}$') {
                throw "Invalid ChangeTime '$rowChangeTime' for $accountName — expected 24hr UTC HH:mm."
            }

            $rowNextChangeDate = ""
            if ($rowNextChangeDateRaw) {
                # Accept common formats as pasted directly from RED-IM/PI exports
                # (M/D/YYYY, MM/DD/YYYY, M/D/YY, YYYY-MM-DD, etc.) and normalize
                # to YYYY-MM-DD for the API. No manual reformatting needed.
                $acceptedFormats = @(
                    "yyyy-MM-dd",
                    "M/d/yyyy", "MM/dd/yyyy", "M/dd/yyyy", "MM/d/yyyy",
                    "M/d/yy", "MM/dd/yy",
                    "yyyy/M/d", "yyyy/MM/dd"
                )
                $parsedDate = $null
                foreach ($fmt in $acceptedFormats) {
                    try {
                        $parsedDate = [datetime]::ParseExact($rowNextChangeDateRaw.Trim(), $fmt,
                            [System.Globalization.CultureInfo]::InvariantCulture)
                        break
                    } catch { }
                }
                if (-not $parsedDate) {
                    # Last resort: culture-aware general parse
                    $ok = [datetime]::TryParse($rowNextChangeDateRaw.Trim(), [ref]$parsedDate)
                    if (-not $ok) { $parsedDate = $null }
                }
                if (-not $parsedDate) {
                    throw "Could not parse NextChangeDate '$rowNextChangeDateRaw' for $accountName — check for typos or an unrecognized date format."
                }
                $rowNextChangeDate = $parsedDate.ToString("yyyy-MM-dd")
            }
            $resultRow.NextChangeDate = $rowNextChangeDate

            $body = [ordered]@{
                AccountName                       = $accountName
                SAMAccountName                    = $row.SAMAccountName
                UserPrincipalName                 = $row.UserPrincipalName
                DomainName                        = $row.DomainName
                AutoManagementFlag                = $true
                FunctionalAccountID               = $FunctionalAccountID
                ChangeFrequencyType               = "xdays"
                ChangeFrequencyDays               = $rowChangeFreqDays
                ChangeTime                        = $rowChangeTime
                ChangePasswordAfterAnyReleaseFlag = $false
                CheckPasswordFlag                 = $true
                ResetPasswordOnMismatchFlag       = $false
                MaxConcurrentRequests             = 1
                ReleaseDuration                   = $DefaultReleaseDuration
                MaxReleaseDuration                = $MaxReleaseDuration
                ApiEnabled                        = $false
            }

            if ($rowNextChangeDate) {
                $body["NextChangeDate"] = $rowNextChangeDate
            }

            if ($seedPw) {
                $pwSecure = Get-CurrentPasswordSecureString -AccountName $accountName -PasswordTable $passwordTable
                $body["Password"] = ConvertFrom-SecureStringPlain $pwSecure
            }

            $bodyJson = $body | ConvertTo-Json -Depth 5

            if ($PSCmdlet.ShouldProcess("$accountName on ManagedSystemID $systemId", "Create Managed Account")) {
                $created = Invoke-RestMethod `
                    -Uri "$ApiBaseUrl/ManagedSystems/$systemId/ManagedAccounts" `
                    -Method POST -WebSession $conn.Session -Headers $conn.Headers `
                    -ContentType "application/json" -Body $bodyJson -ErrorAction Stop

                $resultRow.Status = "Created"
                $resultRow.Detail = "ManagedAccountID $($created.ManagedAccountID)"

                if ($seedPw) {
                    try {
                        $testResult = Invoke-RestMethod `
                            -Uri "$ApiBaseUrl/ManagedAccounts/$($created.ManagedAccountID)/Credentials/Test" `
                            -Method POST -WebSession $conn.Session -Headers $conn.Headers -ErrorAction Stop
                        $resultRow.PasswordValidated = if ($testResult.Success) { "Yes" } else { "NO - MISMATCH, review before relying on checkout" }
                    } catch {
                        $resultRow.PasswordValidated = "Test call failed: $(Get-DetailedErrorMessage $_)"
                    }
                }
            } else {
                $resultRow.Status = "WhatIf"
                $resultRow.Detail = "Would POST to ManagedSystems/$systemId/ManagedAccounts"
                if ($seedPw) { $resultRow.PasswordValidated = "N/A (WhatIf - no account created to test)" }
            }

            # Clear password out of the body/variable immediately
            if ($body.Contains("Password")) { $body["Password"] = $null }
            $bodyJson = $null
        }
        catch {
            $resultRow.Status = "Failed"
            $resultRow.Detail = Get-DetailedErrorMessage $_
        }

        $report.Add([pscustomobject]$resultRow)
    }
}
finally {
    Disconnect-PasswordSafeApi -BaseUrl $ApiBaseUrl -Session $conn.Session -Headers $conn.Headers

    # Release in-memory secure strings
    if ($passwordTable) { $passwordTable.Clear(); $passwordTable = $null }

    if ($PurgeExportAfterRun -and $SecureExportPath) {
        Remove-SecureExportFile -Path $SecureExportPath
    }
}

# ---------------------------------------------------------------------------
# 6. Report (no secrets ever written here)
#    -WhatIf:$false / -Confirm:$false below are deliberate: when this
#    function is invoked with -WhatIf, PowerShell auto-propagates that to
#    EVERY ShouldProcess-aware cmdlet called within it — including New-Item
#    and Export-Csv. Without the override, the report itself gets treated
#    as part of the simulated/skipped work and is never actually written,
#    even though only account creation should be a dry run, not reporting.
# ---------------------------------------------------------------------------
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force -WhatIf:$false | Out-Null
}
$reportFile = Join-Path $OutputPath "Import-ManagedAccounts-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
$report | Export-Csv -Path $reportFile -NoTypeInformation -WhatIf:$false -Confirm:$false

Write-Host "Done. Report: $reportFile"
Write-Host ($report | Group-Object Status | Select-Object Name, Count | Format-Table | Out-String)

$failedRows = $report | Where-Object { $_.Status -eq "Failed" }
if ($failedRows) {
    Write-Host "--- Failed row details (also in the report CSV) ---" -ForegroundColor Yellow
    foreach ($f in $failedRows) {
        Write-Host "$($f.AccountName): $($f.Detail)" -ForegroundColor Yellow
    }
}

} # <-- end of function Start-PWSManagedAccountImport


# =============================================================================
# INVOCATION — edit the values below, then run this whole file (or select
# everything above AND this block and run it together in ISE/console).
#
# Nothing executes until this call runs — pasting the function definition
# alone just defines it, the same as loading a module. Leave -WhatIf in
# place until you've reviewed the dry-run report.
# =============================================================================
Start-PWSManagedAccountImport `
    -CsvPath "C:\Path\To\Your\TestBatch.csv" `
    -ApiBaseUrl "https://[PS-APPLIANCE]/BeyondTrust/api/public/v3" `
    -FunctionalAccountID [FUNCTIONAL-ACCOUNT-ID] `
    -SecureExportPath "C:\Path\To\Your\TestBatch-Passwords.csv" `
    -ServiceNowTask "TASK0000000" `
    -WhatIf
    # -PurgeExportAfterRun   <-- intentionally left out per your instruction to keep it OFF for now
