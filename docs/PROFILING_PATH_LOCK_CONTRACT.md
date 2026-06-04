# Profiling path-lock contract

This contract defines the first fixture/static package for hardening bashqueues profiling path locks. It is contract-first and does not yet replace the dispatch/open path.

## Design rule

Path grants are grants to verified objects and trusted parent directories, not bare strings.

A naive grant such as:

```text
allowed: /tmp/workdir/config_update.sql
```

must be represented as structured evidence:

```json
{
  "schema": "queuebash.path_lock.profile.v1",
  "canonical_path": "/tmp/workdir/config_update.sql",
  "parent": {
    "canonical_path": "/tmp/workdir",
    "device": "259:2",
    "inode": 123456,
    "owner_uid": 1001,
    "mode": "0700"
  },
  "target": {
    "type": "regular-file",
    "device": "259:2",
    "inode": 789012,
    "owner_uid": 1001,
    "mode": "0600"
  },
  "symlink_policy": "deny",
  "hardlink_policy": "constrained",
  "mount_crossing_policy": "deny",
  "open_policy": ["beneath", "nofollow", "no-magiclinks"],
  "write_policy": "existing-file-write"
}
```

## Runtime decisions

Runtime evidence uses schema `queuebash.path_lock.evidence.v1`.

A path-lock decision uses:

```text
allow
block
needs_private_workspace
unsupported
```

Blocking reasons include:

```text
symlink_denied
magiclink_denied
parent_identity_mismatch
final_identity_mismatch
hardlink_denied
mount_crossing_denied
path_escape_denied
shared_tmp_denied
write_policy_mismatch
```

## Private workspace rule

High-risk classes should not receive write grants to shared `/tmp` paths. They should receive a private per-job workspace, and the profile should grant only the required create/write/append operations under that workspace.

## Out of scope for this package

This package does not add live kernel enforcement, mount namespace creation, or dispatch refactoring. It adds the contract, schemas, fixtures, and tests that future enforcement must satisfy.

## Fixture provider contract

`providers.d/path_lock/path_lock_provider.sh` is a fixture-only facade for
contract tests. It evaluates structured grant/observation JSON and returns
`queuebash.path_lock.decision.v1` without opening, writing, chmoding, chowning,
renaming, deleting, or inspecting live target paths.

This deliberately separates the contract from runtime enforcement. The future
runtime implementation must use safe-open semantics bound to trusted parent
objects; the fixture provider only proves that callers and tests agree on the
fail-closed decision vocabulary.

Supported fixture decisions include:

- `symlink_denied`
- `magiclink_denied`
- `path_escape_denied`
- `mount_crossing_denied`
- `parent_identity_mismatch`
- `final_identity_mismatch`
- `file_type_denied`
- `create_outside_approved_root`
- `private_workspace_required`
- `replace_cross_directory_denied`
- `replace_temp_parent_mismatch`
- `shared_tmp_high_risk_denied`

The provider result must remain redacted and must not contain secret values,
provider credentials, shell snippets to execute, or raw file contents.
