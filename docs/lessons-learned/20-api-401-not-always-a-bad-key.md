# Lesson: A 401 From the API Sign-In Endpoint Doesn't Always Mean a Bad Key

The single most useful discovery from a Secrets Safe API proof-of-concept: an API Key
Policy registration existing and being active is **not sufficient by itself**. The
BeyondInsight group containing the `runas` user also needs that API registration
explicitly assigned/selected in User Management. Skip that step and every sign-in call
returns HTTP 401 with `Failed to authenticate due to one or more authentication
rules.` — which reads exactly like a bad or expired key.

Before assuming the key is the problem, check (in this order): the API registration
is active → the registration is assigned to the correct group → the `runas` user is a
member of that group → then look at IP/authentication-rule restrictions. The key
itself is rarely the actual cause once the registration is confirmed active.

**Takeaway:** treat this as the default first hypothesis for any Password Safe API
401, ahead of "maybe the key is wrong." See
[`docs/05-api-authentication-and-session-mechanics.md`](../05-api-authentication-and-session-mechanics.md)
for the full mechanics.
