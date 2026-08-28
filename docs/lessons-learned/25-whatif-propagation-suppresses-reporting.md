# Lesson: `-WhatIf` Silently Suppressed the Diagnostic Report, Not Just the Risky Action

## What I Was Trying to Do

Run a bulk account-creation script in dry-run mode (`-WhatIf`) to validate
CSV parsing, field mapping, and per-account rotation schedules before
letting it actually create anything in Password Safe. The intent was: skip
the account-creation `POST` calls, but still get a full report of what
*would* have happened, since that report is what gets reviewed before
approving a live run.

## What Happened

The dry run completed, printed a summary (`Failed: 2`), and referenced a
report file path — but the report file didn't exist. `Import-Csv` against
that path failed with `FileNotFoundException`.

## Root Cause

When a function using `[CmdletBinding(SupportsShouldProcess = $true)]` is
invoked with `-WhatIf`, PowerShell automatically propagates that WhatIf
context to **every other `ShouldProcess`-aware cmdlet called within that
same function**, not just the one guarded by an explicit
`$PSCmdlet.ShouldProcess(...)` check. `Export-Csv` and `New-Item` both
support `ShouldProcess`. The script's report-writing step —
`New-Item -ItemType Directory ...` and `$report | Export-Csv ...` — had no
explicit override, so both silently became simulated no-ops under the
inherited WhatIf context. The console even printed
`What if: Performing the operation "Export-Csv"...`, which was easy to
misread as a normal, expected dry-run message rather than a sign that a
step meant to always run had been unintentionally skipped.

## What I Did to Fix It

Added explicit `-WhatIf:$false -Confirm:$false` to both the `New-Item` and
`Export-Csv` calls in the reporting section, so they always execute
regardless of the function's own WhatIf state:

```powershell
New-Item -ItemType Directory -Path $OutputPath -Force -WhatIf:$false | Out-Null
$report | Export-Csv -Path $reportFile -NoTypeInformation -WhatIf:$false -Confirm:$false
```

Also added console output of any `Failed`-status rows' detail text
directly, so diagnosing a failure no longer strictly depends on the report
file existing in the first place.

## What I Would Do Differently

Any time a script combines `-WhatIf`-gated risky actions (creation,
deletion, modification) with non-risky bookkeeping actions (logging,
reporting, directory creation) in the same function, audit every
`ShouldProcess`-aware cmdlet in that function individually — don't assume
`-WhatIf` only affects the one call you explicitly wrapped in
`$PSCmdlet.ShouldProcess()`. It affects the whole function's scope.

## Key Takeaway

`-WhatIf` propagation in PowerShell is scope-wide, not call-specific. If a
step must always execute regardless of dry-run state — most commonly,
producing the report that documents what the dry run *would have done* —
it needs an explicit `-WhatIf:$false` override, or it will silently be
skipped right when you need it most.
