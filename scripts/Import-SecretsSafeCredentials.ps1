<#
.SYNOPSIS
    Imports one Safe's worth of credential secrets into BeyondTrust Password Safe Secrets Safe,
    filtered out of a multi-safe shared credentials export CSV.

.DESCRIPTION
    Shared credential exports contain rows for MANY target Safes in a single file
    (column "Password List" = destination Safe name). This script targets ONE Safe per run:
    you specify -SafeName, and the script filters the CSV down to only the rows belonging
    to that Safe before importing. Run it once per Safe.

    Column mapping (Credential export -> Secrets Safe secret):
        System          -> Title
        Password List   -> Safe Name (used as the FILTER key, not written to the secret)
        Username        -> Username
        Password        -> Password
        Comment         -> Notes   (only set if Comment has a value for that row)
        Highlight, Last Change Time, Origin -> ignored

    If the target Safe does not already exist, it is created (POST secrets-safe/safes) before
    import proceeds. Column names are parameterized in case your actual export headers differ
    slightly from the defaults below.

.PARAMETER CsvPath
    Path to the shared credentials export CSV (full export, multiple Safes allowed).

.PARAMETER SafeName
    The target Safe for THIS run. Rows in the CSV are filtered to Password-List-column values
    matching this exactly (case-insensitive, trimmed). Run the script again with a different
    -SafeName for the next Safe.

.PARAMETER AutoCreateSafe
    Default $true. If -SafeName doesn't exist yet, create it via POST secrets-safe/safes.

.PARAMETER SafeDescription
    Description to set if the Safe is created. Optional.

.PARAMETER TeamGroupId
    Optional. Numeric BeyondInsight GroupId. Used two ways:
    1) If the Safe doesn't exist yet, grants this group access on creation (safe-permissions).
    2) Sets OwnerType=Group / OwnerId=<this> on every imported secret (required field on this
       appliance - a 400 "Invalid OwnerType" error otherwise).
    If omitted, imported secrets are owned by the signed-in user (OwnerType=User) instead, and
    a newly-created Safe is left with no group permissions assigned (assign manually).

.PARAMETER SafePermissionFlags
    Permission set to grant $TeamGroupId if provided. Defaults to "Read, Create, Edit, Delete"
    (Regular-teams tier - no Manage).

.PARAMETER TitleColumn
    CSV column mapped to secret Title. Default: "System"

.PARAMETER SafeNameColumn
    CSV column used to filter rows to this run's -SafeName. Default: "Password List"

.PARAMETER UsernameColumn
    CSV column mapped to secret Username. Default: "Username"

.PARAMETER PasswordColumn
    CSV column mapped to secret Password. Default: "Password"

.PARAMETER NotesColumn
    CSV column mapped to secret Notes, only when non-empty for that row. Default: "Comment"

.PARAMETER ApplianceBaseUrl
    Base API URL. Defaults to https://SERVERNAME/BeyondTrust/api/public/v3

.PARAMETER RunAsUser
    Domain\user for the PS-Auth RunAs header. Defaults to <yourdomain.com\username>.

.PARAMETER ServiceNowTask
    Optional ServiceNow task number for traceability. Written into the report filename and summary.

.PARAMETER ReportPath
    Network path to write the results report. UPDATE THIS to your actual reporting path.

.PARAMETER WhatIf
    Dry run. Validates the CSV, resolves/previews the Safe, shows what WOULD happen -
    makes no POST/PUT calls that create or modify anything. Still signs in/out.

.EXAMPLE
    .\Import-SecretsSafeCredentials.ps1 -CsvPath "C:\Temp\shared-creds-export.csv" -SafeName "SS-SecurityTools-SharedCreds" -WhatIf

.EXAMPLE
    .\Import-SecretsSafeCredentials.ps1 -CsvPath "C:\Temp\shared-creds-export.csv" -SafeName "SS-Network-SharedCreds" -TeamGroupId 57 -ServiceNowTask "TASK12345"

.NOTES
    Author:     C.Williams, IT Security Admin
    Created:    August 2026
    Platform:   BeyondTrust Password Safe On-Premises v26.2
    Requires:   PowerShell 5.1, Windows (uses System.Windows.Forms for the API key prompt)

    PLACEHOLDERS TO UPDATE: $ReportPath default, $ApplianceBaseUrl for your appliance, $RunAsUser default.

    SECURITY: Reads plaintext passwords from the input CSV (your responsibility to secure/delete
    that file after import) and transmits them over HTTPS to the appliance. Never logs, echoes,
    or writes passwords OR the API key to the console, transcript, or report file.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$CsvPath,

    [Parameter(Mandatory = $true)]
    [string]$SafeName,

    [bool]$AutoCreateSafe = $true,

    [string]$SafeDescription = "",

    [Nullable[int]]$TeamGroupId = $null,

    [string]$SafePermissionFlags = "Read, Create, Edit, Delete",

    [string]$TitleColumn = "System",
    [string]$SafeNameColumn = "Password List",
    [string]$UsernameColumn = "Username",
    [string]$PasswordColumn = "Password",
    [string]$NotesColumn = "Comment",

    [string]$ApplianceBaseUrl = "https://SERVERNAME/BeyondTrust/api/public/v3",

    [string]$RunAsUser = "yourdomain.com\username",

    [string]$ServiceNowTask = "",

    [string]$ReportPath = "YOUR_FILE_PATH"
)

$ErrorActionPreference = "Stop"

# ── Extract the real API error response body (not just the generic HTTP status text) ──
function Get-RestErrorDetail {
    param($ErrorRecord)

    if ($ErrorRecord.ErrorDetails -and $ErrorRecord.ErrorDetails.Message) {
        return $ErrorRecord.ErrorDetails.Message
    }

    try {
        $respStream = $ErrorRecord.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($respStream)
        $body = $reader.ReadToEnd()
        $reader.Close()
        if ($body) { return $body }
    }
    catch {
        # fall through to generic message below
    }

    return $ErrorRecord.Exception.Message
}

# ── GUI prompt for API key (masked input, never written to disk/console) ────
function Get-ApiKeyFromPrompt {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text            = "BeyondTrust Password Safe API Key"
    $form.Size            = New-Object System.Drawing.Size(440, 160)
    $form.StartPosition   = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox     = $false
    $form.MinimizeBox     = $false
    $form.TopMost         = $true

    $label = New-Object System.Windows.Forms.Label
    $label.Text     = "Paste API Key:"
    $label.Location = New-Object System.Drawing.Point(10, 15)
    $label.AutoSize  = $true
    $form.Controls.Add($label)

    $textbox = New-Object System.Windows.Forms.TextBox
    $textbox.Location              = New-Object System.Drawing.Point(10, 40)
    $textbox.Size                  = New-Object System.Drawing.Size(405, 20)
    $textbox.UseSystemPasswordChar = $true
    $form.Controls.Add($textbox)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text         = "OK"
    $okButton.Location     = New-Object System.Drawing.Point(240, 75)
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($okButton)
    $form.AcceptButton = $okButton

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text         = "Cancel"
    $cancelButton.Location     = New-Object System.Drawing.Point(330, 75)
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($cancelButton)
    $form.CancelButton = $cancelButton

    $form.Add_Shown({ $textbox.Focus() })
    $dialogResult = $form.ShowDialog()

    if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK -or [string]::IsNullOrWhiteSpace($textbox.Text)) {
        $form.Dispose()
        throw "API key entry was cancelled or empty. Aborting - script will not proceed without a key."
    }

    $key = $textbox.Text
    $textbox.Text = ("*" * 20)
    $form.Dispose()
    return $key
}

# ── Setup ────────────────────────────────────────────────────────────────────
$timestamp   = Get-Date -Format "yyyyMMdd-HHmmss"
$reportFile  = Join-Path $ReportPath "SecretsSafeImport_$($SafeName)_$timestamp.csv"
$summaryLine = "Secrets Safe import - Safe: $SafeName - CSV: $CsvPath"
if ($ServiceNowTask) { $summaryLine += " - Task: $ServiceNowTask" }
Write-Host $summaryLine -ForegroundColor Cyan

if (-not (Test-Path $ReportPath)) {
    Write-Warning "Report path '$ReportPath' does not exist or is unreachable. Update -ReportPath. Falling back to current directory for this run."
    $reportFile = Join-Path (Get-Location) "SecretsSafeImport_$($SafeName)_$timestamp.csv"
}

Write-Host "Waiting for API key entry (prompt window)..." -ForegroundColor Cyan
$apiKey = Get-ApiKeyFromPrompt

$headers = @{
    Accept         = "application/json"
    "Content-Type" = "application/json"
    Authorization  = "PS-Auth key=$apiKey; runas=$RunAsUser;"
}
Remove-Variable apiKey

# ── Load, validate, and filter CSV to this Safe ─────────────────────────────
$allRows = Import-Csv -Path $CsvPath
if ($allRows.Count -eq 0) {
    throw "CSV at '$CsvPath' contains no rows."
}

$csvColumns = $allRows[0].PSObject.Properties.Name
foreach ($col in @($TitleColumn, $SafeNameColumn, $UsernameColumn, $PasswordColumn)) {
    if ($csvColumns -notcontains $col) {
        throw "CSV is missing expected column '$col'. Found columns: $($csvColumns -join ', '). Adjust the -*Column parameters if your export uses different headers."
    }
}
$hasNotesCol = $csvColumns -contains $NotesColumn

$targetSafeTrimmed = $SafeName.Trim()
$rows = $allRows | Where-Object { $_.$SafeNameColumn.Trim() -ieq $targetSafeTrimmed }
$skippedOtherSafeCount = $allRows.Count - $rows.Count

Write-Host "CSV contains $($allRows.Count) total row(s). $($rows.Count) match Safe '$SafeName' ($SafeNameColumn). $skippedOtherSafeCount row(s) belong to other Safes and will be ignored this run." -ForegroundColor Cyan

if ($rows.Count -eq 0) {
    throw "No rows in the CSV have '$SafeNameColumn' = '$SafeName'. Check the exact value in the export (case/whitespace) or confirm -SafeName."
}

# ── Sign in ──────────────────────────────────────────────────────────────────
$Session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$results = New-Object System.Collections.Generic.List[object]

try {
    $signInResponse = Invoke-RestMethod `
        -Uri "$ApplianceBaseUrl/Auth/SignAppIn" `
        -Method POST `
        -Headers $headers `
        -WebSession $Session

    Write-Host "Signed in as: $($signInResponse.UserName) (UserId: $($signInResponse.UserId))" -ForegroundColor Green
    $currentUserId   = $signInResponse.UserId
    $currentUserName = $signInResponse.UserName

    # ── Resolve or create target Safe ───────────────────────────────────────
    $folderLookup = Invoke-RestMethod `
        -Uri "$ApplianceBaseUrl/Secrets-Safe/Folders?FolderName=$([uri]::EscapeDataString($SafeName))" `
        -Method GET `
        -Headers $headers `
        -WebSession $Session

    $targetFolder = $folderLookup | Where-Object { $_.Name -eq $SafeName } | Select-Object -First 1
    $folderId = $null

    if (-not $targetFolder) {
        if (-not $AutoCreateSafe) {
            throw "Safe '$SafeName' was not found and -AutoCreateSafe is `$false. Create it first or re-run with auto-create allowed."
        }

        if ($PSCmdlet.ShouldProcess("BeyondTrust Password Safe", "Create Safe '$SafeName'")) {
            $safeBody = @{ Name = $SafeName; Description = $SafeDescription } | ConvertTo-Json

            $newSafe = Invoke-RestMethod `
                -Uri "$ApplianceBaseUrl/secrets-safe/safes" `
                -Method POST `
                -Headers $headers `
                -WebSession $Session `
                -Body $safeBody

            $folderId = $newSafe.Id
            Write-Host "Created Safe '$SafeName' (Id: $folderId)" -ForegroundColor Green

            if ($TeamGroupId) {
                $permBody = @{
                    PrincipalType   = 1
                    PrincipalID     = $TeamGroupId
                    PermissionFlags = $SafePermissionFlags
                    ExpiresOn       = $null
                } | ConvertTo-Json

                Invoke-RestMethod `
                    -Uri "$ApplianceBaseUrl/secrets-safe/safes/$folderId/safe-permissions" `
                    -Method PUT `
                    -Headers $headers `
                    -WebSession $Session `
                    -Body $permBody | Out-Null

                Write-Host "Granted GroupId $TeamGroupId '$SafePermissionFlags' on '$SafeName'" -ForegroundColor Green
            }
            else {
                Write-Warning "No -TeamGroupId provided. '$SafeName' has NO group permissions assigned yet - assign them manually before anyone but IT Sec Admins can use it."
            }
        }
        else {
            Write-Host "[WhatIf] Would create Safe '$SafeName' - skipping import preview since no Folder ID is available in dry-run." -ForegroundColor Yellow
        }
    }
    else {
        $folderId = $targetFolder.Id
        Write-Host "Resolved existing Safe '$SafeName' to Folder ID: $folderId" -ForegroundColor Green
    }

    # ── Import loop ──────────────────────────────────────────────────────────
    $rowNum = 0
    foreach ($row in $rows) {
        $rowNum++
        $title    = $row.$TitleColumn
        $username = $row.$UsernameColumn
        $password = $row.$PasswordColumn

        if ([string]::IsNullOrWhiteSpace($title) -or
            [string]::IsNullOrWhiteSpace($username) -or
            [string]::IsNullOrWhiteSpace($password)) {
            $results.Add([pscustomobject]@{
                LineNumber = $rowNum
                Title      = $title
                Status     = "Skipped"
                Detail     = "Missing required field ($TitleColumn/$UsernameColumn/$PasswordColumn)"
            })
            Write-Warning "[$rowNum] Skipped '$title' - missing required field."
            continue
        }

        $noteValue = $null
        if ($hasNotesCol -and -not [string]::IsNullOrWhiteSpace($row.$NotesColumn)) {
            $noteValue = $row.$NotesColumn
        }

        $body = @{
            Title    = $title
            Username = $username
            Password = $password
        }
        if ($noteValue) { $body.Notes = $noteValue }

        if ($TeamGroupId) {
            $body.OwnerType = "Group"
            $body.OwnerId   = $TeamGroupId
        }
        else {
            $body.OwnerType = "User"
            $body.Owners    = @(@{ OwnerId = $currentUserId; Owner = $currentUserName; Email = "" })
        }

        $bodyJson = $body | ConvertTo-Json -Depth 5

        if (-not $folderId) {
            $results.Add([pscustomobject]@{
                LineNumber = $rowNum
                Title      = $title
                Status     = "WhatIf"
                Detail     = "Would create in new Safe '$SafeName' (not yet created in dry-run)"
            })
            continue
        }

        if ($PSCmdlet.ShouldProcess("Safe '$SafeName'", "Create secret '$title'")) {
            try {
                $response = Invoke-RestMethod `
                    -Uri "$ApplianceBaseUrl/Secrets-Safe/Folders/$folderId/secrets" `
                    -Method POST `
                    -Headers $headers `
                    -WebSession $Session `
                    -Body $bodyJson

                $results.Add([pscustomobject]@{
                    LineNumber = $rowNum
                    Title      = $title
                    Status     = "Success"
                    Detail     = "SecretId: $($response.Id)"
                })
                Write-Host "[$rowNum] Created '$title'" -ForegroundColor Green
            }
            catch {
                $errMsg = Get-RestErrorDetail -ErrorRecord $_
                $results.Add([pscustomobject]@{
                    LineNumber = $rowNum
                    Title      = $title
                    Status     = "Failed"
                    Detail     = $errMsg
                })
                Write-Warning "[$rowNum] Failed '$title' - $errMsg"
            }
        }
        else {
            $results.Add([pscustomobject]@{
                LineNumber = $rowNum
                Title      = $title
                Status     = "WhatIf"
                Detail     = "Would create in folder $folderId"
            })
        }
    }
}
finally {
    if ($Session) {
        try {
            Invoke-RestMethod `
                -Uri "$ApplianceBaseUrl/Auth/Signout" `
                -Method POST `
                -Headers $headers `
                -WebSession $Session | Out-Null
            Write-Host "Signed out." -ForegroundColor Cyan
        }
        catch {
            Write-Warning "Sign-out call failed (session may still be active on the appliance): $($_.Exception.Message)"
        }
    }
}

# ── Report ───────────────────────────────────────────────────────────────────
$results | Export-Csv -Path $reportFile -NoTypeInformation -Encoding UTF8

$successCount = ($results | Where-Object Status -eq "Success").Count
$failCount    = ($results | Where-Object Status -eq "Failed").Count
$skipCount    = ($results | Where-Object Status -eq "Skipped").Count
$whatIfCount  = ($results | Where-Object Status -eq "WhatIf").Count

Write-Host ""
Write-Host "-- Summary --------------------------" -ForegroundColor Cyan
Write-Host "Safe:              $SafeName"
Write-Host "Rows in CSV:       $($allRows.Count)"
Write-Host "In scope (matched):$($rows.Count)"
Write-Host "Other-safe rows:   $skippedOtherSafeCount (ignored this run)"
if ($whatIfCount -gt 0) { Write-Host "WhatIf:            $whatIfCount" -ForegroundColor Yellow }
Write-Host "Succeeded:         $successCount" -ForegroundColor Green
Write-Host "Failed:            $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Gray" })
Write-Host "Skipped (bad row): $skipCount" -ForegroundColor Yellow
Write-Host "Report:            $reportFile"
if ($ServiceNowTask) { Write-Host "SNOW Task:         $ServiceNowTask" }