# Pre-Deployment Checklist (Generic Template)

Adapted from a vendor professional-services pre-deployment checklist and field
experience. Fill in the "Owner" and "Status" columns for your own project; delete rows
that don't apply to your scope.

| # | Task | Detail | Required | Owner | Status |
|---|---|---|---|---|---|
| 1 | Project initiation questionnaire | Complete before kickoff call | Yes | | |
| 2 | Use-case detail | Document intended use cases (managed accounts, Secrets Safe, SSH/RDP session management, etc.) | Yes | | |
| 3 | AD bind account | Read-only account for directory integration; create exclusively for this platform's use | Yes | | |
| 4 | Functional accounts | One or more accounts with change-password capability per platform, created exclusively for this platform's use | Yes | | |
| 5 | Credentialed scan/discovery accounts | Administrative-scope account(s) per platform for discovery; separate from functional accounts | Yes | | |
| 6 | AD groups for roles | Create security groups for each role that logs into the platform (Requestors, Approvers, Administrators, Auditors, etc.) | Yes | | |
| 7 | AD groups for managed-account scoping | Create groups/OUs identifying which accounts should be managed vs. excluded | Yes | | |
| 8 | Firewall rules | Apply required firewall rules (see [`templates/firewall-rules-reference.md`](../templates/firewall-rules-reference.md)) | Yes | | |
| 9 | Appliance IP & DNS | Have addressing info ready before deployment | Yes | | |
| 10 | Appliance deployment | Deploy per vendor deployment guide, stop at initial welcome/setup screen if professional services will complete configuration | Yes | | |
| 11 | Email/SMTP for notifications | Determine sending address; confirm SMTP auth requirements | Yes | | |
| 12 | Appliance software update connectivity | Confirm appliance can reach vendor update endpoints, or plan an alternate update method | Yes | | |
| 13 | Test assets | 1–3 non-production test assets per platform to be managed | Yes | | |
| 14 | Test accounts | 1–3 test accounts per platform | Yes | | |
| 15 | Test functional accounts | Test-scope functional account per platform | Yes | | |
| 16 | Test user accounts | 3 test users, one per role group, for workflow validation | Yes | | |
| 17 | One-to-one account matching (if in scope) | Decide prefix/suffix vs. directory-attribute matching approach; prepare corresponding AD groups | Conditional | | |
| 18 | Resource availability | Ensure network/firewall, AD, DBA, and platform-admin resources are available during the deployment window | Yes | | |

## Notes

- Keep this table in your project tracker, not just this repo — it's meant as a
  starting skeleton, not a live tracking artifact.
- Items 3–7 (accounts and AD groups) typically have the longest lead time if your
  organization requires change-control tickets for new service accounts — start these
  first.
