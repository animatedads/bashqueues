# bashqueues integrity assets

The `integrity` asset family protects critical classes from silently running a
changed script, configuration file, or payload tree.

This is deliberately separate from bashqueues code/plugin signing:

- code/plugin signing answers: *is bashqueues or this plugin trusted?*
- integrity assets answer: *is the operational payload still the approved version?*

## Facilities

### `integrity:file_sha256`

Strict single-file check.

```bash
queue_class_shared_asset integrity file_sha256 /opt/jobs/month_end.sh sha256=<64-hex-sha256>
```

### `integrity:manifest_verified`

Checks every path listed in a manifest.

```bash
queue_class_shared_asset integrity manifest_verified /etc/bashqueues/manifests/month_end.manifest
```

Accepted manifest line forms:

```text
<sha256> <absolute-path>
sha256 <absolute-path> <sha256>
```

Blank lines and `#` comments are ignored.

### `integrity:tree_manifest_verified`

Checks a manifest against a specific tree root.  Relative paths are resolved
under the tree root; absolute paths must still remain inside the tree.

```bash
queue_class_shared_asset integrity tree_manifest_verified /opt/batch/month_end manifest=/etc/bashqueues/manifests/month_end.tree
```

## Manifest safety

By default, manifest files under `$QUEUEBASH_ROOT` are refused.  That prevents a
normal queue user from changing both the payload and the manifest.  Tests and
explicit development classes may opt in with:

```bash
allow_user_manifest=1
```

Production manifests should be operator-owned, outside the user-writable queue
root, and not group/other writable.

## Class template

`classes/IMMUTABLE_PAYLOAD.env` is a strict template for critical jobs that must
not run if their approved manifest changes.
