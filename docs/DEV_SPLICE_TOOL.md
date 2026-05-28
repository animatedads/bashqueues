# queue dev splice

`queue dev splice` is a constrained developer tool for anchored text splicing.
It exists to replace repeated ad hoc Python one-liners such as `Path(...).read_text().replace(...)` during internal refactor work.

It is intentionally not a general scripting interface.

## Contract

Schema:

```text
queuebash.dev_splice_response.v1
```

Supported operations:

```bash
queue dev splice --file FILE --after TEXT --insert TEXT [--if-missing TEXT] [--dry-run] [--json]
queue dev splice --file FILE --before TEXT --insert TEXT [--if-missing TEXT] [--dry-run] [--json]
queue dev splice --file FILE --replace TEXT --with TEXT [--if-present TEXT] [--dry-run] [--json]

queue dev splice --file FILE --after-file NEEDLE_FILE --insert-file INSERT_FILE [--if-missing TEXT] [--dry-run] [--json]
queue dev splice --file FILE --before-file NEEDLE_FILE --insert-file INSERT_FILE [--if-missing TEXT] [--dry-run] [--json]
queue dev splice --file FILE --replace-file OLD_FILE --with-file NEW_FILE [--all] [--dry-run] [--json]
```

## Safety rules

- Operates on one target file only.
- Fails if the file does not exist.
- Fails if no anchor/needle is provided.
- Fails if more than one transformation mode is provided.
- `--after` and `--before` fail if the anchor is missing.
- `--replace` and `--replace-file` require explicit `--with` or `--with-file`; omission is never treated as deletion.
- `--replace` fails if the old text appears more than once unless `--all` is used.
- `--dry-run` never modifies the target file.
- Writes are atomic using a temp file followed by `mv`/`replace` semantics.
- Existing file permissions are preserved.
- It does not create `queuebash.sh.bak.*` or `*.devpatch.*` artifacts.
- File-based anchors, inserts, and replacement blocks are read inside the helper so trailing newlines are preserved exactly.
- Inserted text is not executed, sourced, evaluated, or interpreted as shell.

## Idempotency gates

`--if-missing TEXT` skips insertion/replacement if `TEXT` is already present.

`--if-present TEXT` skips replacement if `TEXT` is absent.

JSON output distinguishes:

```text
changed=true
changed=false
skipped=true
error=true
```

## Example: behaviour-lock installer stub

```bash
cat > /tmp/installer_stub_block <<'STUB'
_queue_install_bundled_classes(){ :; }
_queue_install_bundled_env_profiles(){ :; }
STUB

queue dev splice \
  --file tests/internal_refactor_job_resolution_behaviour_lock_smoke.sh \
  --after 'source ./queuebash.sh' \
  --insert-file /tmp/installer_stub_block \
  --if-missing '_queue_install_bundled_classes(){ :; }' \
  --json
```

## Relationship to function patching

For Bash function replacement, prefer the existing function-aware tools:

```bash
queue dev extract --file queuebash.sh FUNCTION
queue dev symbols --file queuebash.sh --function FUNCTION --json
queue dev flow --file queuebash.sh --function FUNCTION --json
queue dev patch --file queuebash.sh --function FUNCTION --source /tmp/new_function --json
```

Use `queue dev splice` for anchored text additions or block replacement where a function-level patch is not the right shape.
