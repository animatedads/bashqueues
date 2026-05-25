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

Policy lookup order is:

1. shared/admin policy folder, normally `/etc/bashqueues/policies.d`
2. personal queue-root policy folder, `$QUEUEBASH_ROOT/policies.d`
3. bundled repository policy folder, `policies.d`

If a shared/admin policy and a personal policy have the same kind/name, the
shared/admin policy wins.  This lets an operator define site policy centrally
without being shadowed by a user-local file.  Disabled policies are not loaded.

Useful commands:

```bash
queue policies list
queue policies list sandbox
queue policies show sandbox strict
queue policies show seccomp docker-default
queue policies create sandbox my-safe-policy --from strict
queue policies edit sandbox my-safe-policy
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


## Policy snapshots

At submit time, bashqueues resolves the class defaults and job override names,
loads the selected sandbox/seccomp policy files, and writes a snapshot into the
`.job` record.  The snapshot includes:

```text
SECURITY_POLICY_SNAPSHOT_AT=...
SANDBOX_POLICY_NAME=...
SANDBOX_POLICY_ORIGIN=shared|personal|bundled
SANDBOX_POLICY_SHA256=...
SANDBOX_POLICY_SYSTEMD_PROPERTIES=( ... )
SECCOMP_POLICY_NAME=...
SECCOMP_POLICY_ORIGIN=shared|personal|bundled
SECCOMP_POLICY_SHA256=...
SECCOMP_POLICY_SYSTEMD_PROPERTIES=( ... )
```

The worker prefers the per-QID snapshot when building `systemd-run` arguments.
That means an already-submitted job remains auditable and reproducible even if
a same-named policy is edited later.  Submit-time exception overlays such as
`--sandbox-override`, `--seccomp-allow`, `--drop-cap`, and `--add-port` are
then applied on top and shown in `queue explain`.

## Default policy set

The bundled policy set now includes:

```text
sandbox/off
sandbox/queue-default
sandbox/network-none
sandbox/restrict-egress
sandbox/strict

seccomp/off
seccomp/queue-default
seccomp/docker-default
seccomp/strict
```

`queue-default` is the recommended starting point for general queue classes:
restrict public egress at the sandbox layer and use Docker-style seccomp
filtering at the syscall layer.  Use `strict` for untrusted local scripts and
`off` only when the operator intentionally wants no policy.


### 0.17.17 Class Creator seccomp policy chooser

The Queue Manager Class Creator exposes both sandbox and seccomp policy fields. Use `*` on the default seccomp field to choose from `queue policies list seccomp`. F2 commands include `classcreator seccomp docker-default` and `classcreator seccomp-allow @debug`.

## Exception overlay visibility

Submit-time security exceptions are stored in the job record and reported by
`queue explain` under `Exception overlays`:

```text
Exception overlays
  sandbox:           OVERRIDE strict -> off via job flag
  seccomp:           HOLE PUNCHED allowing '@debug'
  runtime caps:      REMOVED 'no-network-tools'
  runtime ports:     ADDED '443'
```

This means a strict class can be relaxed for a single QID while keeping the
audit trail visible later.
