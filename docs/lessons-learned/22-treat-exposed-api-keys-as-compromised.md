# Lesson: Treat Any API Key That Touched a Terminal, Screenshot, or Transcript as Exposed

If a key was ever visible in interactive troubleshooting output — printed to a
console, pasted into a chat transcript, captured in a screenshot, or left in shell
history — rotate it and restore any authentication rules (e.g. explicit source-IP
restrictions) that were relaxed for testing, even if you're confident nobody else saw
it.

This is a "treat it as burned, don't audit whether it's actually burned" policy —
cheaper than being wrong about who had visibility.

**Takeaway:** never print `$headers`, `$headers.Authorization`, or a `$Session` object
during any recorded or shared troubleshooting session — all three can carry the
Authorization header or session token. Use a dedicated, least-privilege API
registration for migration work, and disable or restrict it once the work is done.
