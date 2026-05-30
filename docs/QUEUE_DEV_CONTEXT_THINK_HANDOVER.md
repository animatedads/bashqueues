# queue dev context / think / handover

`0.18.50` implements the remaining lightweight Bob12 dev workflow cockpit commands from the accepted contract stage:

```text
queue dev context [--json] [--tag TAG] [--kind KIND] [--status STATUS] [--limit N] [--full-corpus]
queue dev think --text TEXT [--subject SUBJECT] [--tag TAG...] [--authority AUTHORITY] [--json]
queue dev handover [--json] [--since ITEM_ID] [--tag TAG] [--full-corpus]
```

The commands are deliberately bounded. They exist to reduce AI session drift and make development state reviewable without requiring an assistant to know or dump the full scratchpad corpus.

## `queue dev context`

`context` returns the current working set. By default it filters out inactive lifecycle states:

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

Use `--full-corpus` only when a reviewer explicitly needs broad state. JSON output uses:

```text
queuebash.dev_workflow.context.v1
```

The output includes a base version, filters, scratchpad item summaries, attempt/file-registry counts, and warnings if optional ledgers cannot be read.

## `queue dev think`

`think` records a safe, auditable planning note in the scratchpad. It is not a private chain-of-thought dump. The note should be a short engineering plan, rationale, or assumption that a reviewer can inspect.

JSON output uses:

```text
queuebash.dev_workflow.think.v1
```

The full text is stored in the scratchpad record; the JSON response includes a hash, subject, tags, and generated item ID.

## `queue dev handover`

`handover` returns a reviewer-friendly delta summary for the current tree:

```text
deliveries
open_tasks
known_landmines
next
changed_files
attempts
```

It uses scratchpad, attempt ledger, and file-registry state where available. Default mode is `delta`; `--full-corpus` must be explicit.

JSON output uses:

```text
queuebash.dev_workflow.handover.v1
```

## Safety boundaries

These commands do not run tests, approve work, apply patches, call live providers, or mutate external systems. `think` mutates only the development scratchpad by adding a planning record. `context` and `handover` are read-only summaries.
