# queue dev workflow JSON schemas

This document summarises the schema names and required top-level keys for the proposed queue dev workflow commands.  The authoritative machine-readable examples for this release live under `schemas/dev_workflow/`.

The schema names are intentionally versioned.  Incompatible output changes must use a new schema name.

| Command | Schema | Required keys |
| --- | --- | --- |
| `queue dev context` | `queuebash.dev_workflow.context.v1` | `schema`, `status`, `mode`, `filters`, `items`, `warnings` |
| `queue dev think` | `queuebash.dev_workflow.think.v1` | `schema`, `status`, `item_id`, `kind`, `authority`, `text_hash`, `tags` |
| `queue dev attempt begin` / `queue dev attempt end` | `queuebash.dev_workflow.attempt.v1` | `schema`, `status`, `attempt_id`, `phase`, `authority` |
| `queue dev evidence record` | `queuebash.dev_workflow.evidence.v1` | `schema`, `status`, `evidence_id`, `attempt_id`, `result` |
| `queue dev handover` | `queuebash.dev_workflow.handover.v1` | `schema`, `status`, `mode`, `base_version`, `deliveries`, `open_tasks`, `known_landmines`, `next` |
| `queue dev scratchpad status set` | `queuebash.dev_workflow.scratchpad_status.v1` | `schema`, `status`, `item_id`, `old_status`, `new_status` |
| `queue dev scratchpad supersede` | `queuebash.dev_workflow.supersede.v1` | `schema`, `status`, `item_id`, `superseded_by` |

## Safety constraints

- JSON producers must generate IDs; callers must not be required to invent canonical IDs.
- Unknown statuses, missing attempts, and missing replacement records must fail closed.
- `queue dev think` must store reviewable planning summaries, not private reasoning dumps.
- `queue dev evidence record` must not imply acceptance.
- `queue dev handover` and `queue dev context` must default to a working set unless `--full-corpus` is explicit.
