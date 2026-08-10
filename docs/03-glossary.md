# Glossary

| Term | Definition |
|---|---|
| **Managed System** | A target asset/platform registered in Password Safe (server, database, network device, directory, cloud account, etc.) |
| **Managed Account** | A credential on a Managed System actively rotated/owned by Password Safe |
| **Functional Account** | A service account used *by* Password Safe to perform discovery/rotation/management actions against a platform |
| **Bind Account** | Read-only AD/LDAP service account used to integrate Password Safe with your directory for authentication |
| **Smart Rule** | Saved query that dynamically filters Managed Systems/Accounts by criteria |
| **Smart Group** | The dynamic group produced by a Smart Rule; used to scope role and policy assignment |
| **Address Group** | Named collection of IP ranges/subnets used to scope discovery or Smart Rules |
| **Safe** | Secrets Safe container for static, non-rotated secrets, permissioned per-Safe |
| **Access Policy** | Rules governing how a credential/session can be accessed (approval, time window, MFA, checkout duration, plaintext vs. injection) |
| **Credential Injection** | Launching a session (RDP/SSH/etc.) where Password Safe supplies the credential directly to the target without displaying it to the user |
| **Discovery** | Scanning/agent-based process to find candidate systems/accounts for onboarding |
| **RED-IM** | BeyondTrust Privileged Identity (legacy on-prem PAM product, reached End of Life; common migration source into Password Safe) |
| **UVM / U-Series appliance** | BeyondTrust's on-premises virtual/physical appliance form factor |
| **ADFS** | Active Directory Federation Services — a common on-prem SAML Identity Provider used with Password Safe SSO |
| **SID (Security Identifier)** | Unique AD identifier for a user/group; required form for group claims when Password Safe's User Mapping type is set to Active Directory |
| **Break-glass account** | Local emergency-access account used to bypass AD/SSO auth path during an outage or misconfiguration |
