# queue dev workflow command contracts

This document is a contract-first roadmap for the next generation of `queue dev` workflow commands.  It records the command names, authority model, expected JSON shapes, lifecycle transitions, and safety boundaries before implementation.

Most commands in this document remain **proposed contracts only**.  As of 0.18.44, only `queue dev scratchpad status set` and `queue dev scratchpad supersede` are implemented; the remaining workflow commands must not be treated as implemented until a later release wires explicit handlers into `queuebash.sh`, updates help output, and adds focused command tests.

## Goals

The workflow command set exists to reduce AI-session drift, duplicate scratchpad contracts, weak attempt/evidence linkage, and endless active scratchpad items.  It gives maintainers and AI assistants a small cockpit for loading current context, recording plans, binding validation evidence to attempts, and handing over a precise delta.

The design principles are:

```text
fail closed
command-owned ID/schema generation
working-set default unless --full-corpus is explicit
composable scratchpad output
no requirement that the AI know the full scratchpad corpus
no automatic acceptance from validation output
```

## Proposed command surface

```text
queue dev context [--json] [--tag TAG] [--kind KIND] [--status STATUS] [--limit N] [--full-corpus]
queue dev think --text TEXT [--json] [--tag TAG...] [--subject SUBJECT]
queue dev attempt begin --text TEXT [--json] [--tag TAG...] [--based-on ITEM_ID...]
queue dev attempt end ATTEMPT_ID --status STATUS [--text TEXT] [--json]
queue dev evidence record --attempt ATTEMPT_ID --text TEXT [--file FILE...] [--command COMMAND] [--status STATUS] [--json]
queue dev handover [--since ITEM_ID|--tag TAG] [--json] [--full-corpus]
queue dev scratchpad status set ITEM_ID --status STATUS [--reason TEXT] [--json]
queue dev scratchpad supersede ITEM_ID --by ITEM_ID [--reason TEXT] [--json]
```

These names intentionally layer on top of the existing `queue dev scratchpad` ledger rather than replacing it.

## Status vocabulary

The initial status vocabulary is:

```text
active
in_progress
blocked
superseded
resolved
accepted
rejected
failed
```

Status transitions are deliberately conservative:

```text
active -> in_progress|blocked|superseded|resolved|accepted|rejected
in_progress -> blocked|resolved|accepted|rejected|failed
blocked -> active|in_progress|superseded|rejected
resolved -> accepted|rejected|superseded
accepted -> superseded
rejected -> superseded
failed -> active|in_progress|superseded
superseded -> superseded
```

A status transition must include the previous status, new status, authority, timestamp, and optional reason in JSON output.  Unknown statuses must fail closed.

## `queue dev context`

`context` returns the current working set for a Bob/session.  By default it must not dump the entire scratchpad corpus.  It should prefer active/current items and the most recent authoritative decisions.

Expected JSON shape:

```json
{
  "schema": "queuebash.dev_workflow.context.v1",
  "status": "ok",
  "mode": "working_set",
  "filters": {"tag": ["bob12"], "status": ["active"]},
  "base_version": "0.18.43",
  "items": [],
  "warnings": []
}
```

`--full-corpus` is explicit because the whole scratchpad may be large, stale, duplicated, or not relevant to the current work.

## `queue dev think`

`think` records a short auditable planning note.  It is not a private chain of thought dump.  It is a concise engineering plan or rationale that a reviewer can safely read.

Expected JSON shape:

```json
{
  "schema": "queuebash.dev_workflow.think.v1",
  "status": "ok",
  "item_id": "DEVTHINK-EXAMPLE",
  "kind": "think",
  "authority": "developer",
  "subject": "queue dev workflow contracts",
  "text_hash": "sha256:example",
  "tags": ["bob12", "queue-dev"]
}
```

The command should store the full text in the scratchpad record, but JSON summaries may expose a hash/redacted snippet where appropriate.

## `queue dev attempt begin/end`

Attempts provide a parent record for a bounded unit of engineering work.  They should make validation evidence and failure notes attach to a named attempt instead of floating loosely in the ledger.

`attempt begin` creates an active attempt.  `attempt end` closes it with a terminal or follow-up status.

Expected begin JSON shape:

```json
{
  "schema": "queuebash.dev_workflow.attempt.v1",
  "status": "ok",
  "attempt_id": "DEVATTEMPT-EXAMPLE",
  "phase": "begin",
  "authority": "developer",
  "based_on": ["ITEM-1"],
  "tags": ["bob12", "queue-dev"]
}
```

Expected end JSON shape:

```json
{
  "schema": "queuebash.dev_workflow.attempt.v1",
  "status": "ok",
  "attempt_id": "DEVATTEMPT-EXAMPLE",
  "phase": "end",
  "result": "resolved",
  "evidence": ["DEVEVIDENCE-EXAMPLE"]
}
```

## `queue dev evidence record`

Evidence records validation facts under an attempt.  It may reference commands, files, hashes, manifests, logs, or test names.  It must not claim acceptance unless the authority explicitly records acceptance.

Expected JSON shape:

```json
{
  "schema": "queuebash.dev_workflow.evidence.v1",
  "status": "ok",
  "evidence_id": "DEVEVIDENCE-EXAMPLE",
  "attempt_id": "DEVATTEMPT-EXAMPLE",
  "result": "pass",
  "commands": ["bash -n queuebash.sh"],
  "files": ["validation.log"]
}
```

## `queue dev handover`

`handover` returns a reviewer-friendly delta: current base, changed files, open tasks, resolved attempts, known landmines, and next recommended work.  The default should be a working-set handover, not a full corpus dump.

Expected JSON shape:

```json
{
  "schema": "queuebash.dev_workflow.handover.v1",
  "status": "ok",
  "mode": "delta",
  "base_version": "0.18.43",
  "deliveries": [],
  "open_tasks": [],
  "known_landmines": [],
  "next": []
}
```

## `queue dev scratchpad status set`

`status set` updates an existing scratchpad item lifecycle state.  It should be the primary pruning mechanism for noisy scratchpad corpora.  Tools should filter out `superseded`, `resolved`, `accepted`, and `rejected` records by default unless requested.

Expected JSON shape:

```json
{
  "schema": "queuebash.dev_workflow.scratchpad_status.v1",
  "status": "ok",
  "item_id": "ITEM-1",
  "old_status": "active",
  "new_status": "superseded",
  "reason": "replaced by corrected merge note"
}
```

## `queue dev scratchpad supersede`

`supersede` creates a typed relation between an obsolete item and a replacement.  It is not deletion.  The original record must remain available for audit, but default working-set views should prefer the replacement.

Expected JSON shape:

```json
{
  "schema": "queuebash.dev_workflow.supersede.v1",
  "status": "ok",
  "item_id": "OLD-ITEM",
  "superseded_by": "NEW-ITEM",
  "reason": "version corrected"
}
```

## Non-goals for this release

This release implements only the scratchpad lifecycle handlers (`status set` and `supersede`).  It does not implement `context`, `think`, `attempt begin/end`, `evidence record`, or `handover`; it does not make `queue dev test` write evidence automatically; and it does not add dynamic JSON probes that invoke broad `queue dev` dispatcher/init paths, because reviewer sandboxes have shown those paths can hang.

## Staged implementation sequence

```text
0.18.43 docs/schemas/static tests for dev workflow commands
0.18.44 scratchpad lifecycle: status set, supersede
0.18.45 attempt/evidence linkage: attempt begin/end, evidence record
0.18.46 context/handover/delta
0.18.47 validate/scope-check gates
```
