# bashqueues execution environments

Execution environments are first-class test/live/staging profile records. They are separate from sandbox/seccomp.

Sandbox/seccomp answers: what is this job allowed to do?

Execution environment answers: which world is this job running inside?

## Files

Profiles live under:

```text
$QUEUEBASH_ROOT/envs.d/<name>.env
```

Bundled examples are installed from `envs.d/` on queue initialisation:

```text
test.env
staging.env
live.env
```

## Commands

```bash
queue env list
queue env show live
queue env show live --json
queue env validate live
queue env path live
```

## Class linkage

Classes select a profile with:

```bash
CLASS_EXEC_ENV=live
```

The class default is stamped into jobs as:

```bash
EXEC_ENV=live
```

Use the env asset to enforce the profile at dispatch:

```bash
queue_class_shared_asset env profile_required live
queue_class_shared_asset env secret_scope live profile=live
queue_class_shared_asset env endpoint_scope live profile=live
```

## Chroot status

0.17.76 is phase 1: profile metadata, UI, validation, class linkage, and asset gates. It does not yet apply `chroot` or systemd `RootDirectory=` at runner level.

Future runner enforcement can map profile fields to systemd options such as `RootDirectory=`, `BindPaths=`, `BindReadOnlyPaths=`, and `ReadWritePaths=`.
