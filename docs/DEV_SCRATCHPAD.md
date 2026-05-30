# queue dev scratchpad

`queue dev scratchpad` is a file-backed, authority-stamped engineering ledger for AI-assisted bashqueues development.

This package implements `0.18.24_internal_dev_scratchpad_import_contract` only. It is storage/state infrastructure for future workflows. It does not call `queue dev test`, does not render prompts, does not call AI providers, and does not refactor `queue()`, job resolution, or splice semantics.

## Path resolution

Scratchpad path resolution is intentionally a small shell seam:

```bash
_queue_dev_scratchpad_path() {
    if [[ -n "${QUEUEBASH_DEV_SCRATCHPAD:-}" ]]; then
        printf '%s\n' "$QUEUEBASH_DEV_SCRATCHPAD"
    else
        printf '%s\n' "$(_queue_root)/dev/scratchpad.json"
    fi
}
```

Default path:

```text
$(_queue_root)/dev/scratchpad.json
```

Override:

```text
QUEUEBASH_DEV_SCRATCHPAD=/path/to/scratchpad.json
```

## Schemas

The ledger schema is:

```text
queuebash.dev_scratchpad.v1
```

Each item uses:

```text
queuebash.dev_scratchpad_item.v1
```

The pruned working view returned by `next --json` uses:

```text
queuebash.dev_scratchpad_working_set.v1
```

The future test runner result schema `queuebash.dev_test_result.v1` can be stored manually as evidence through `queue dev scratchpad evidence TASK_ID --json-file result.json`, but this release does not call `queue dev test`.

## Authority and confidence

Authority types are documented and represented in the ledger metadata:

```text
architect
team_leader
reviewer
coding_agent
tool
source_tree
test_runner
external_ai
imported_doc
```

Confidence values are:

```text
authoritative
accepted
observed
inferred
proposed
rejected
stale
```

`import --from-tree` always records lightweight observed facts with:

```text
authority.type=source_tree
confidence=observed
```

Coding-agent authority may add attempts, evidence, blockers, and challenge notes. It must not silently delete or downgrade architect/team_leader/reviewer contracts. This initial implementation is append-oriented for agent-originated work; reviewer/team_leader commands record decisions rather than destructive rewrites.

## Kinds and statuses

Kinds:

```text
contract
design_goal
architecture
task
attempt
evidence
failure
success
decision
toolchain
known_landmine
blocker
challenge
done_note
imported_fact
```

Statuses:

```text
active
pending
done
rejected
stale
proposed
blocked
removed
```

## Commands

```text
queue dev scratchpad help
queue dev scratchpad init --project NAME [--json]
queue dev scratchpad import --from-tree DIR [--project NAME] [--json]
queue dev scratchpad add --kind KIND --authority AUTHORITY --text TEXT [--tag TAG...] [--json]
queue dev scratchpad task --text TEXT [--authority team_leader] [--json]
queue dev scratchpad attempt ITEM_ID --note TEXT [--json]
queue dev scratchpad evidence ITEM_ID --summary TEXT [--raw-log PATH] [--verdict VERDICT] [--json]
queue dev scratchpad evidence ITEM_ID --json-file result.json [--summary TEXT] [--verdict VERDICT] [--json]
queue dev scratchpad done ITEM_ID --note TEXT [--authority reviewer] [--json]
queue dev scratchpad reject ITEM_ID --note TEXT [--authority reviewer] [--json]
queue dev scratchpad fail ITEM_ID --note TEXT [--json]
queue dev scratchpad bump-fail ITEM_ID [--json]
queue dev scratchpad list [--json] [--status STATUS] [--kind KIND] [--tag TAG]
queue dev scratchpad delete ITEM_ID [--authority reviewer] [--note TEXT] [--json]
queue dev scratchpad next [--json]
queue dev scratchpad export [--json]
queue dev scratchpad explain ITEM_ID
```

## Import contract

`queue dev scratchpad import --from-tree .` is intentionally lightweight. It records observed source-tree facts only, including:

- `QUEUEBASH_VERSION`
- README top release heading
- CHANGELOG top release heading
- presence or absence of key files/directories
- standing cleanup facts such as `assets.d/net_usage.sh` absent and `caps.d/net_usage.sh` present if present
- current `queue dev` usage lines
- whether a scratchpad command is present in the source

It does not attempt broad semantic analysis of the project.

## `list` and `delete`

`queue dev scratchpad list` provides a compact human-readable item inventory. `--json` returns a stable machine-readable summary list, and optional `--status`, `--kind`, and `--tag` filters allow focused review without exporting the full ledger.

`queue dev scratchpad delete ITEM_ID` is intentionally a soft delete. It marks the item status as `removed` and appends a reviewer/team_leader/architect decision note, preserving auditability. It requires high-authority `architect`, `team_leader`, or `reviewer` authority and should not be used by coding agents to erase higher-authority decisions.

## `next --json` versus `export --json`

`queue dev scratchpad next --json` returns a pruned working set, not the full ledger.

It includes active architect/team_leader/reviewer contracts, the active task, active known landmines, active toolchain notes, latest relevant evidence, and counters for the active task. Done, rejected, stale, removed, and unrelated historical items are excluded. Attempts are compressed: the working view keeps the first and latest attempt for the active task and omits middle attempts.

`queue dev scratchpad export --json` returns the full chronological ledger with no pruning.

## Evidence limits

Evidence should store summaries and pointers, not giant logs. `--raw-log PATH` stores the path and a bounded tail. `--json-file result.json` records a pointer and the payload schema, which is how a future `queuebash.dev_test_result.v1` file can be attached manually.

## Explicitly out of scope

This release includes no prompt renderer, no `queue dev test` integration, no AI provider calls, no database provider, no git notes provider, no enterprise scratchpad provider, and no automatic reviewer decisions.
