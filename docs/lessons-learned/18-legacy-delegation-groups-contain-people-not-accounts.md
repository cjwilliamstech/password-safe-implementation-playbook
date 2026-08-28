# Lesson: Legacy Delegation Groups Often Contain People, Not Service Accounts

A common misread when migrating from a legacy platform: a delegation group like
`P_RED_DBAs` contains the **people** who are allowed to retrieve a given service
account's password — not the service account itself. The service account is
associated with the group as a delegation rule *inside* the legacy tool, not through
normal AD group membership.

**Takeaway:** when mapping legacy delegation groups to new role-based-access groups,
keep the direction of the relationship straight — same people, new group, new
platform, not "convert the group into the account."
