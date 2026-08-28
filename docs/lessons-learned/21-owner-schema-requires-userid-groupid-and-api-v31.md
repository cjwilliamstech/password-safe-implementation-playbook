# Lesson: Owner Objects Need UserId/GroupId, Not a Generic Id, and Require API v3.1

Creating a Secrets Safe secret with an `Owners` collection returns HTTP 400 (`Invalid
OwnerType`) unless: the request targets **API version 3.1** (`?version=3.1` on the
create-secret call), `OwnerType` is explicitly set (`User` or `Group`), and each object
in `Owners` uses `UserId` or `GroupId` — a generic `Id` property is silently rejected.

```json
// Rejected
{ "Owners": [ { "Id": 1234 } ] }

// Accepted
{
  "OwnerType": "User",
  "Owners": [ { "UserId": 1234 } ]
}
```

**Takeaway:** JSON property *order* doesn't matter for this endpoint — only property
*names* and nesting do. Capture the actual API response body when debugging a 400;
"Invalid OwnerType" is a much clearer signal than a generic HTTP status code (see
[lesson 26](26-surface-api-error-bodies-not-status-codes.md)).
