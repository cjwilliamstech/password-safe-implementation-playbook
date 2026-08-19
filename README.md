# BeyondTrust Password Safe — Implementation Playbook

A field reference built from a real on-premises **BeyondTrust Password Safe** deployment,
including migration off a legacy PAM platform (RED-IM / BeyondTrust Privileged Identity),
Secrets Safe rollout, managed account onboarding, and SAML/SSO integration via ADFS.

> **What this is:** generalized checklists, runbooks, and gotchas distilled from a live
> multi-entity utility deployment.
>
> **What this is NOT:** this repo contains **no** real hostnames, IP addresses, domain
> names, credentials, API keys, or environment-specific identifiers. All examples use
> placeholders (e.g. `<appliance-fqdn>`, `<domain.tld>`, `10.x.x.x`). Replace them with
> your own environment's values before use — never commit real values back to a public repo.

## Why this exists

Password Safe deployments are one-time-per-environment events, and a lot of hard-won
context (why a setting behaves the way it does, which docs page actually matches the UI,
what breaks silently) evaporates once the project closes out. This repo is meant to be
the thing I wish I'd had on day one of the next implementation.

## Structure

| Folder | Contents |
|---|---|
| [`docs/`](docs/) | Narrative lessons learned, architecture decisions and rationale, key concepts, and a glossary of terms that trip people up |
| [`checklists/`](checklists/) | Reusable, fill-in-the-blank checklists for each phase of a deployment |
| [`templates/`](templates/) | Generic reference docs (firewall rules, Smart Rule examples, functional account setup, AD group mapping, ADFS/SAML troubleshooting) |
| [`scripts/`](scripts/) | Working automation, e.g. [`Import-SecretsSafeCredentials.ps1`](scripts/Import-SecretsSafeCredentials.ps1) — bulk-imports a legacy shared-credentials export into Secrets Safe via the REST API (the web UI's CSV importer only supports personal folders, not team Safes) |
| [`runbooks/`](runbooks/) | Step-by-step procedures for specific high-value workflows (legacy platform migration, break-glass access) |

## How to use this

1. Start with [`docs/01-lessons-learned.md`](docs/01-lessons-learned.md) for the narrative — what the project actually looked like phase by phase.
2. Read [`docs/04-architecture-decisions.md`](docs/04-architecture-decisions.md) for the design patterns and the reasoning behind them (functional account model, OU structure, the three-tier Smart Rule model, Secrets Safe governance).
3. Pull the relevant checklist from `checklists/` when you kick off the equivalent phase in your own project.
4. Copy templates from `templates/` and fill in your environment's specifics locally — **do not commit filled-in versions with real values to a public repo.**
5. See [`scripts/README.md`](scripts/README.md) before running the bulk import script — it documents every parameter, the CSV column mapping, and the placeholders you need to update for your environment.
6. Reference `docs/03-glossary.md` any time a term (Smart Rule, Smart Group, Address Group, Safe, Secrets Safe, functional account) is ambiguous.

## Scope covered

- Managed account onboarding (Windows/AD-managed systems): Smart Rules, Smart Groups, Address Groups, Access Policies
- Secrets Safe for static, non-rotating shared credentials (migrated from a legacy PAM tool)
- Bulk import into team Safes via the REST API (the UI's CSV import is personal-folder-only)
- SAML/SSO via ADFS as IdP, including the most common silent-failure mode (claim type mismatch)
- Firewall rule planning for appliance ↔ managed system communication
- Legacy platform decommission / migration runbook

## Disclaimer

This reflects one organization's environment, one appliance version generation, and one
point in time. BeyondTrust's UI and behavior change between releases — always cross-check
against the current official docs: https://docs.beyondtrust.com/bips/docs/welcome-to-password-safe

## License

MIT — see [`LICENSE`](LICENSE). Use, fork, and adapt freely.
