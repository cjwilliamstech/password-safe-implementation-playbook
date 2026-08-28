# Lesson: The "All Managed Systems" Catch-All Smart Group Doesn't Support Role Assignment

An "All Managed Systems" (or similarly named catch-all) Smart Group typically does
**not** support direct role assignment. This is a platform constraint, not a
misconfiguration — don't spend time troubleshooting why a role won't attach to it.

**Takeaway:** if you need broad role coverage, build a Smart Rule that's
inclusive-but-specific (e.g. "all platforms, all in-scope OUs") rather than relying on
the built-in catch-all group.
