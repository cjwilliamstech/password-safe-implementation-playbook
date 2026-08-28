# Lesson: The UI's CSV Importer Only Works for Personal Folders, Not Team Safes

Password Safe's CSV import feature in the web UI is scoped to a **user's personal
folder**, not team/shared Safes. If your migration involves importing a few dozen
existing shared credentials into a team Safe, the UI path is a dead end.

The workaround is the **REST API** — authenticate with an API key, then `POST` the
credential data to the Secrets Safe folder/import endpoint. See
[`scripts/`](../../scripts/) for a working (sanitized) script built around this.

Practical notes from building this:

- Store the API key as a machine-scoped environment variable on the automation host,
  not in the script.
- The automation host needs a firewall path to the appliance on TCP 443 — request this
  early, it's a standard network-change-request lead time item, not a same-day
  approval.
- If your legacy platform exports data in an unusual encoding, check it *before* you
  spend an afternoon debugging why field values look corrupted (see
  [lesson 19](19-utf16-encoding-in-legacy-exports.md)).
