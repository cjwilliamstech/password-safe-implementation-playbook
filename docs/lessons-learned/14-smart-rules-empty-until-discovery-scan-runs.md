# Lesson: Smart Rules Return Nothing Until a Discovery Scan Has Actually Run

Smart Rules only evaluate what's already in the inventory. If no discovery scan has
populated the inventory yet, a perfectly well-built Smart Rule will show zero results
— which looks identical to a misconfigured rule.

**Takeaway:** always run an IP discovery or credentialed scan first, *then*
troubleshoot the Smart Rule if it's still empty.
