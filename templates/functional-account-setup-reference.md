# Functional Account Setup Reference

Generic registration details and grant scripts for the standard functional account
set described in [`docs/04-architecture-decisions.md`](../docs/04-architecture-decisions.md).
Replace bracketed placeholders with your own values — do not commit real account
names, passwords, or instance identifiers.

## Registration table

| Alias | Entity Type | Platform | Domain | Purpose |
|---|---|---|---|---|
| `<FA-AD-Bind>` | Directory | Active Directory | `<domain>` | Bind/read-only AD queries |
| `<FA-AD-Func>` | Directory | Active Directory | `<domain>` | AD password rotation |
| `<FA-Windows>` | Asset | Windows | `<domain>` | Windows local account management |
| `<FA-SQL>` | Database | MS SQL Server | — | SQL account management |
| `<FA-Oracle>` | Database | Oracle | — | Oracle account management |

Remember: the dropdown for a Managed System's functional account only shows accounts
matching **both** Entity Type and Platform exactly, and only accounts whose Workgroup
matches the Managed System's Workgroup (see lessons-learned #6 and #7).

## SQL Server functional account

Run on **each** SQL instance you plan to manage:

```sql
CREATE LOGIN [<FA-SQL>] WITH PASSWORD = '<set via your normal secure provisioning process>';
GRANT CONNECT SQL TO [<FA-SQL>];
GRANT ALTER ANY LOGIN TO [<FA-SQL>];

-- Only if you also need to manage sysadmin-level accounts:
-- ALTER SERVER ROLE sysadmin ADD MEMBER [<FA-SQL>];
```

## Oracle functional account

```sql
CREATE USER <FA-Oracle> IDENTIFIED BY <set via your normal secure provisioning process>;
GRANT CONNECT TO <FA-Oracle>;
GRANT ALTER USER TO <FA-Oracle>;
GRANT SELECT ON DBA_USERS TO <FA-Oracle>;
```

## Discovery scan types

| Scan Type | Credentials Required | Discovers | Use For |
|---|---|---|---|
| IP Discovery | None | IP addresses only | Populating asset inventory quickly, low-risk first pass |
| Discover Local Accounts | OS credential | Systems + local user accounts | Windows local account discovery |
| Detailed Discovery Scan | OS **and** database credential | Systems + services + tasks + users + databases | Full discovery including SQL/Oracle accounts |

**Note:** Detailed Discovery Scan requires both an OS credential and a database
credential simultaneously — without both, you cannot get past the credentials step
in the scan wizard, even if you only care about one or the other for a given target.

## Practical tips

- Launching a scan from an asset's context menu (rather than typing IPs manually)
  pre-populates the target scope from the Smart Rule/Smart Group you're already
  looking at — more scalable once you're past the pilot phase.
- Run scans in a staging/report-only mode for the first pass on any new scope, and
  review the results before letting a Smart Rule act on them.
