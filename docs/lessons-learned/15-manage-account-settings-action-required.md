# Lesson: "Manage Account Settings" Action Is Required Even When Every Rotation Option Is Off

A Managed Account Smart Rule with "Discover accounts for management" enabled will
throw an error if it doesn't also have a **Manage Account Settings** action attached —
even if every setting inside that action is toggled off.

**Takeaway:** add the action with defaults disabled as a safe placeholder during
initial validation, then turn settings on deliberately once you're ready.
