# Lesson: The Built-In Local Administrators Role May Only Accept Individual Users, Not AD Groups

If you want group-based admin access to the appliance console itself, don't assume you
can drop an AD group directly into the built-in local Administrators-equivalent role —
depending on your version, it may only accept individual users.

**Takeaway:** maintain a dedicated AD group mapped in through the normal
role-assignment path for admin access, rather than relying on the built-in role to
accept a group.
