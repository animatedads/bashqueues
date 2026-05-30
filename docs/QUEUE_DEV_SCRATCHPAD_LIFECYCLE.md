# Queue dev scratchpad lifecycle commands

This release implements the first staged command handlers from the Bob12 dev workflow contract: explicit scratchpad lifecycle transitions and supersession links.

The goal is to reduce scratchpad drift without deleting audit history. Old decisions, failed proposals, duplicate tasks, and stale contracts should be marked with lifecycle metadata so default views can focus on the current working set while `export --json` remains a full chronological ledger.

## Commands

```bash
queue dev scratchpad status set ITEM_ID --status STATUS [--reason TEXT] [--authority reviewer] [--json]
queue dev scratchpad supersede OLD_ITEM_ID --by NEW_ITEM_ID [--reason TEXT] [--authority reviewer] [--json]
```

Both commands are authority-gated. `architect`, `team_leader`, and `reviewer` may change lifecycle state. Lower-authority actors may still add ordinary attempt/evidence/failure records, but they must not silently rewrite lifecycle authority.

## Status vocabulary

Supported item statuses are:

```text
active
pending
in_progress
done
resolved
accepted
rejected
stale
proposed
blocked
failed
superseded
archived
removed
```

Default working-set behaviour treats these as non-current unless explicitly requested through a full export or status-filtered list:

```text
done
resolved
accepted
rejected
stale
superseded
archived
removed
```

`blocked`, `failed`, `pending`, `proposed`, `in_progress`, and `active` remain visible by default because they may still require action.

## `status set`

`status set` changes one item status and appends a child decision note. It does not delete or rewrite the original text.

JSON response schema:

```json
{
  "schema": "queuebash.dev_workflow.scratchpad_status.v1",
  "status": "ok",
  "item_id": "SP-OLD",
  "old_status": "active",
  "new_status": "resolved",
  "note_id": "SP-NOTE"
}
```

## `supersede`

`supersede` marks one item as replaced by another item. It sets:

```text
old.status = superseded
old.superseded_by = NEW_ITEM_ID
old.relations.superseded_by = NEW_ITEM_ID
new.relations.supersedes += OLD_ITEM_ID
```

It also appends a child decision note against the old item. This is not deletion; the older item remains available in `export --json` and can be inspected with `explain`.

JSON response schema:

```json
{
  "schema": "queuebash.dev_workflow.supersede.v1",
  "status": "ok",
  "item_id": "SP-OLD",
  "old_status": "active",
  "new_status": "superseded",
  "superseded_by": "SP-NEW",
  "note_id": "SP-NOTE"
}
```

## View contract

- `queue dev scratchpad next --json` emits the pruned working set and excludes superseded/resolved/accepted/rejected/stale/archived/removed items.
- `queue dev scratchpad list --json` defaults to current/actionable records.
- `queue dev scratchpad list --all --json` includes all records.
- `queue dev scratchpad export --json` remains the complete audit ledger.

## Non-goals

This release does not implement `queue dev context`, `queue dev think`, `queue dev attempt begin/end`, `queue dev evidence record`, or `queue dev handover` handlers. It does not make validation commands mutate scratchpad state automatically, and it does not refactor queue dispatch.
