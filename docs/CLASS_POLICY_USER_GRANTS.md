# Class policy per-user standing grants

The class policy statement can delegate narrow security exception values to
specific queue users.  This is for standing operational permissions, not for
one-off command approvals.

Example site policy:

```bash
CLASS_POLICY_USER_WEBADMINS_ALLOW_ADD_PORTS="80 1080 8080"
CLASS_POLICY_USER_WEBADMINS_ALLOW_DROP_CAPS="only-port"
```

With that policy, the `webadmins` queue user may request those ports without a
per-command authorisation.  A different user, for example `dba`, still follows
the normal class policy requirement and must provide `--reason` or a signed
`--authorisation`, depending on the active policy.

Supported grant suffixes:

```text
ALLOW_SANDBOX_OVERRIDES
ALLOW_SECCOMP_ALLOWS
ALLOW_DROP_CAPS
ALLOW_ADD_PORTS
ALLOW_SANDBOX_POLICIES
ALLOW_SECCOMP_POLICIES
```

Values are space or comma separated.  `*` or `all` grants all values for that
specific grant type, but this should be avoided in shared policy unless the
operational role genuinely needs it.

User names are normalised for variable names by converting to upper case and
changing non-alphanumerics to underscores.  For example, `web-admins` becomes:

```bash
CLASS_POLICY_USER_WEB_ADMINS_ALLOW_ADD_PORTS="80 1080 8080"
```

Command-specific grants can be used when a standing grant should only apply to a
known command hash:

```bash
CLASS_POLICY_USER_WEBADMINS_COMMAND_0123456789ABCDEF_ALLOW_ADD_PORTS="8080"
```

The command hash is the queue command hash used by authorisations; either the
full SHA256 or the first 16 hex characters may be used in the variable name.
