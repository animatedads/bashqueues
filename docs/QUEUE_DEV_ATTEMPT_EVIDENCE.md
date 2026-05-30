# queue dev attempt/evidence linkage

`queue dev attempt` and `queue dev evidence` provide a bounded development-attempt ledger for AI-assisted and reviewer-assisted engineering work.

Implemented command surface in 0.18.46:

```text
queue dev attempt begin --text TEXT [--tag TAG...] [--based-on ITEM_ID...] [--authority AUTHORITY] [--json]
queue dev attempt end ATTEMPT_ID --status STATUS [--text TEXT] [--authority AUTHORITY] [--json]
queue dev evidence record --attempt ATTEMPT_ID --text TEXT [--file FILE...] [--command COMMAND...] [--status STATUS] [--authority AUTHORITY] [--json]
```

The ledger is stored under:

```text
$QUEUEBASH_ROOT/dev/attempts.json
```

or, when explicitly set for tests/tools:

```text
$QUEUEBASH_DEV_ATTEMPTS
```

## Purpose

Attempts make a bounded unit of engineering work explicit. Evidence records validation facts under that attempt so a reviewer can see which commands, files, logs, and manifests supported a change.

Validation output remains evidence only. It does not self-author acceptance. A reviewer or Team Leader still records acceptance in the scratchpad.

## Attempt lifecycle

`attempt begin` creates an active attempt with:

```text
attempt_id
text and text_hash
tags
based_on item IDs
created_at / updated_at
history[]
evidence[]
```

`attempt end` closes the attempt with one of these terminal statuses:

```text
resolved
accepted
rejected
failed
superseded
blocked
```

The `accepted` status is supported for compatibility with reviewer-led workflows, but normal validation commands must not set it automatically.

## Evidence records

`evidence record` requires an existing attempt. It records:

```text
evidence_id
attempt_id
result
text and text_hash
commands[]
files[] with exists/size/md5 where available
created_at
```

Allowed evidence statuses:

```text
pass
fail
warning
info
blocked
skipped
```

## Security boundaries

These commands do not execute the recorded commands. They only store evidence metadata supplied by the caller. They must not introduce generic shell execution, live provider calls, or automatic acceptance.

