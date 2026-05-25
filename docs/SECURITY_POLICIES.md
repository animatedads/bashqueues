# bashqueues security policy files

Sandbox and seccomp launch settings are policy-file driven.

Bundled policies live in:

```text
policies.d/sandbox/*.env
policies.d/seccomp/*.env
```

When a queue root is initialised, bundled policies are copied to:

```text
$QUEUEBASH_ROOT/policies.d/sandbox/*.env
$QUEUEBASH_ROOT/policies.d/seccomp/*.env
```

Local policy files in the queue root override bundled policies of the same name.
Disabled policies are not loaded.

Useful commands:

```bash
queue policies list
queue policies list sandbox
queue policies show sandbox strict
queue policies show seccomp docker-default
```

Classes and submissions still use the same names:

```bash
CLASS_DEFAULT_SANDBOX_LEVEL=strict
CLASS_DEFAULT_SECCOMP_PROFILE=docker-default

queue submit job --sandbox network-none --seccomp docker-default -- command
```

The difference is that `strict`, `network-none`, `restrict-egress`, and
`docker-default` are now policy names, not hard-coded launch profiles.

A sandbox policy may define:

```bash
SANDBOX_SYSTEMD_PROPERTIES=(
  "PrivateNetwork=yes"
)
SANDBOX_DIRECT_PREFIX=(unshare --net -r --)
SANDBOX_DIRECT_WARNING="direct runner cannot fully enforce this policy"
```

A seccomp policy may define:

```bash
SECCOMP_SYSTEMD_PROPERTIES=(
  "SystemCallArchitectures=native"
  "SystemCallFilter=~@clock @debug @module @mount"
)
```

Policy files are shell data files. Treat queue-root policy edits as operator
configuration and keep them under the same trust/audit model as class files.
