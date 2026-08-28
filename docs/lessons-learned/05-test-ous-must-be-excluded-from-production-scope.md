# Lesson: Test/Scratch OUs Will Pollute Production Smart Rules if Not Explicitly Excluded

Any OU used purely for appliance testing during initial validation needs to be
**explicitly excluded** once you move toward production onboarding — otherwise it
keeps quietly feeding into whatever Smart Rules or Directory Queries were originally
scoped broadly during early testing.

**Takeaway:** treat "exclude test/scratch OUs" as a required step in the transition
from pilot to production scope, not an optional cleanup task.
