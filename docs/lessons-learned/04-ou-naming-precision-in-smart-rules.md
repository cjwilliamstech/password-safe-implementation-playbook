# Lesson: OU Naming Precision Matters in Smart Rules

If your AD has near-duplicate OU names — one with a trailing space, one without, at
different levels of the tree, or differing only in casing — Smart Rule and directory
query logic will happily match the wrong one. There's no warning; the rule just
quietly scopes to a different (or additional) set of accounts than you intended.

**Takeaway:** double-check exact OU names — copy them directly from AD (`Get-ADOrganizationalUnit`
or the ADUC properties pane) rather than retyping from memory — before building Smart
Rules against them.
