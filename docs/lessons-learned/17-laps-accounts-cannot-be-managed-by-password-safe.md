# Lesson: LAPS-Managed Local Accounts Cannot Be Touched by Password Safe

If Windows LAPS (including the version built into Server 2019/2022) manages a local
account via GPO, Password Safe will fail to change that account's password with an
"account is controlled by external policy" error.

**Takeaway:** check for LAPS (`gpresult /r | Select-String "LAPS"` on the target, or
check GPO scope) *before* onboarding local accounts for rotation — this isn't a
misconfiguration you can fix on the Password Safe side, it's a genuine conflict
between two tools claiming the same responsibility.
