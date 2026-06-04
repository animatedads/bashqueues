# Path locking security model

`queuebash` path profiling must not treat an approved path string as proof that the runtime object is still safe. A profile entry such as `/tmp/workdir/config_update.sql` is only a label until the runtime binds it to the expected parent directory, object identity, file type, and safe-open policy.

## Threat model

The rejected class of attack is:

```text
authorised path string -> symlink/hardlink/mount trick -> different object at use time
```

A hostile or compromised job must not be able to turn an approved write path into a write to another object by replacing a leaf path, replacing a parent directory, traversing `..`, using procfs magic links, crossing an unapproved mountpoint, or relying on shared `/tmp` races.

## Required profile evidence

A profiled write grant should record, at minimum:

```text
canonical_path
parent_canonical_path
parent_device
parent_inode
parent_owner_uid
parent_mode
final_device/final_inode for existing-file writes
final_type
final_owner_uid
final_mode
symlink_policy
hardlink_policy
mount_crossing_policy
open_policy
write_policy
```

The contract is intentionally stronger than string comparison. Existing-file writes bind to the final device/inode. Create-only grants bind to the trusted parent directory identity and deny symlink final components. Replace grants must be expressed as a separate operation and constrained to the same trusted directory.

## Safe-open requirements

Runtime enforcement should use safe-open semantics equivalent to:

```text
open beneath the approved parent directory object
deny symlinks by default
deny procfs magic links by default
deny path traversal outside the approved root
deny unprofiled mountpoint crossing
verify final device/inode for existing-file writes
fail closed on race, ambiguity, or permission drift
```

On Linux systems that support it, an implementation can map this to `openat2`-style constraints such as `RESOLVE_BENEATH`, `RESOLVE_NO_SYMLINKS`, `RESOLVE_NO_MAGICLINKS`, and explicit final `fstat` checks. The contract does not require one syscall in the first package; it requires that future enforcement preserve these semantics.

## Parent directory locking

Locking only the leaf is insufficient. The parent directory must be verified because replacing the parent can redirect the same relative path to a different object. Writable shared directories are high risk and should be rejected or remapped for high-risk classes.

Preferred high-assurance workspaces are private per-job directories such as:

```text
/run/queuebash/jobs/<qid>/work
/var/lib/queuebash/jobs/<qid>/work
```

with mode `0700`, owned by the job runner identity, and not shared between jobs.

## Operation-specific permissions

The profile must distinguish:

```text
existing-file-write
create-only
append-only
atomic-replace
delete
chmod/chown
```

These are not interchangeable. For example, `existing-file-write` requires the same final device/inode as the profiled object, while `create-only` requires the same trusted parent and an absent leaf opened with exclusive create semantics.

## Explainability

`queue explain` and JSON status should eventually show path-lock evidence without leaking sensitive paths where policy says to hash or redact them:

```json
{
  "schema": "queuebash.path_lock.evidence.v1",
  "status": "blocked",
  "reason": "symlink_denied",
  "canonical_path": "/run/queuebash/jobs/QID/work/output.sql",
  "parent_identity_ok": true,
  "final_identity_ok": false,
  "safe_open_policy": "beneath,nofollow,no-magiclinks",
  "write_policy": "existing-file-write"
}
```

## Fail-closed rule

Unknown, stale, ambiguous, unresolvable, symlinked, magic-linked, parent-drifted, inode-drifted, world-writable shared, or mount-crossing paths must block unless an explicit signed policy grants that exact exception.

## Fixture helper boundary

The path-lock fixture helper is not a security boundary. It exists so Bob lanes
can validate the contract before a runtime safe-open enforcer is wired into job
dispatch. A passing fixture does not grant runtime write access by itself.

Security requirements preserved by the helper contract:

- it must not open the requested target path;
- it must not follow links;
- it must not create, replace, append, delete, chmod, or chown files;
- it must not treat a path string match as sufficient evidence;
- it must emit only redacted decision evidence.

Future enforcement may use `openat2`/`openat` style mechanics, mount namespaces,
read-only bind mounts, private tmpfs workspaces, or equivalent platform controls,
but those controls are intentionally outside this fixture-only package.
