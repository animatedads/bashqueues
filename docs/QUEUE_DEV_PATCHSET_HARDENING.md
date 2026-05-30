# Queue Dev Patchset Hardening

`0.18.49` tightens the `queue dev files` registry and `queue dev patchset` export path for multistream work.

## Rules

- A missing old file MD5 is not evidence that a file is unchanged.
- A missing old file MD5 means the file is new, unbaselined, or imported from an older registry.
- New or unbaselined files must remain visible in `queue dev files changed` and `queue dev patchset create`.
- Patchsets must describe outcomes clearly before apply.
- Apply scripts must refuse conflicting pre-existing target files.

## Scan behaviour

`queue dev files scan --json` refreshes the current MD5, size, status, and changed flag for each tracked file. It now emits:

```json
{
  "missing_baseline_md5": 1,
  "scan_records": [
    {
      "relpath": "example.sh",
      "md5": "...",
      "size": 123,
      "baseline_md5": null,
      "missing_baseline_md5": true,
      "changed": true
    }
  ]
}
```

The scan does not invent a baseline for unbaselined files. That keeps new-file and imported-registry state visible to patchset export.

## Patchset manifest behaviour

`queue dev patchset create` now writes summary and precondition metadata into `manifest.json`:

```json
{
  "summary": {
    "total_entries": 1,
    "modified_files": 0,
    "new_or_unbaselined_files": 1,
    "missing_baseline_backups": 1,
    "function_preconditions": 0
  },
  "entries": [
    {
      "change_type": "new_or_unbaselined_file",
      "file_old_md5": null,
      "precondition": {
        "allow_absent_target_for_new_file": true,
        "allow_matching_existing_new_file": true
      }
    }
  ]
}
```

## Inspect command

Use:

```bash
queue dev patchset inspect --patchset patch.zip --json
queue dev patchset inspect --patchset patch.zip --target /path/to/tree --json
```

With a target, the embedded precondition checker reports explicit outcomes:

- `ready_new_file_absent`
- `already_applied`
- `conflict_existing_new_file`
- `ready_file_baseline`
- `ready_function_baseline`
- `conflict_function_baseline`
- `missing_target`

The goal is to make multistream outcomes explicit: fully ready, already applied, conflict, missing target, or requires full-file reconciliation.
