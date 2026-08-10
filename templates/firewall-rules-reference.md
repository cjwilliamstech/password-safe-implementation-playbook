# Firewall Rules Reference (Generic)

Adapted from vendor pre-deployment documentation. Use `<PS-Nodes>` to mean the
appliance/cluster address(es); replace all placeholders with your real ranges when you
build your actual change request — don't commit the filled-in version to a public repo.

| Short Description | Source | Destination | Protocol / Port |
|---|---|---|---|
| Linux server password change | `<PS-Nodes>` | Linux targets | TCP 22 |
| HP iLO password change | `<PS-Nodes>` | iLO endpoints | TCP 22 |
| Dell DRAC password change | `<PS-Nodes>` | DRAC endpoints | TCP 22 |
| Windows server password change | `<PS-Nodes>` | All Windows endpoints | TCP 445 |
| Web interface | Everywhere (or user population range) | `<PS-Nodes>` | TCP 443 |
| Kerberos password changes | `<PS-Nodes>` | Domain Controllers in site | TCP/UDP 464 |
| Oracle DB password changes | `<PS-Nodes>` | Oracle DB targets | TCP 1521 (or custom instance port) |
| MSSQL DB password changes | `<PS-Nodes>` | SQL DB targets | TCP 1433 (or custom instance port) |
| RACF password changes | `<PS-Nodes>` | RACF nodes | TCP 22 |
| RDP session proxy (inbound) | Everywhere (or user population range) | `<PS-Nodes>` | TCP 4489 |
| RDP session proxy (outbound to target) | `<PS-Nodes>` | All Windows endpoints | TCP 3389 |
| RDP session proxy (outbound to target, SMB) | `<PS-Nodes>` | All Windows endpoints | TCP 445 |
| SSH session proxy (inbound) | Everywhere (or user population range) | `<PS-Nodes>` | TCP 4422 |
| SSH session proxy (outbound to target) | `<PS-Nodes>` | All *nix endpoints | TCP 22 |
| Managed account service restart | `<PS-Nodes>` | All Windows endpoints | TCP 135, 1024–4099, 50000–65535 |
| Discovery scan | `<PS-Nodes>` | All targets in scope | TCP 21, 22, 23, 25, 80, 110, 135, 139, 443, 445, 554, 1433, 1521 (Oracle), 3306 (MySQL), 3389 |
| REST API / bulk import automation | Automation host(s) | `<PS-Nodes>` | TCP 443 |

## Practical notes

- These change requests almost always route through a formal network approval queue —
  submit as early in the project as possible, not when you're ready to start testing.
- The API/automation rule (last row) is easy to forget because it isn't in most vendor
  checklists by default — add it explicitly if you're planning any REST API-based bulk
  operations (see [`secrets-safe-bulk-import.ps1`](secrets-safe-bulk-import.ps1)).
- Session proxy ports (RDP/SSH) are bidirectional in *role*: inbound from the user
  population to the appliance, then outbound from the appliance to the actual target —
  make sure both legs are covered, they're easy to only half-request.
