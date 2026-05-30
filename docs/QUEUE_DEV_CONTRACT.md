# queue dev contract

`queue dev` is the controlled internal development API for bashqueues. It is intended for AI-assisted and human-assisted maintenance where inspection, patching, review, validation, and evidence need to be repeatable and auditable.

This contract documents the command surface that must remain stable unless a release explicitly updates this document, the help text, and the corresponding tests.

## Command surface

The accepted command surface is:

```text
queue dev functions [--file FILE] [--json] [prefix]
queue dev locate FUNCTION [--json]
queue dev extract FUNCTION [--file FILE] [--json]
queue dev scope [--json] [--prefix PREFIX]
queue dev patch --file FILE --function FUNCTION --source SOURCE [--json] [--no-syntax-check]
queue dev splice --file FILE (--after TEXT|--before TEXT|--replace TEXT --with TEXT) [--insert TEXT] [--dry-run] [--json]
queue dev test [--run] [--name NAME] [--timeout SEC] [--json] -- COMMAND...
queue dev test result JOBID [--root DIR] [--json]
queue dev comment --file FILE --function FUNCTION --message TEXT [--changelog] [--json]
queue dev diff --file FILE [--function FUNCTION] [--json]
queue dev strip --file FILE --function FUNCTION [--json]
queue dev rollback --file FILE --function FUNCTION [--json]
queue dev symbols --file FILE [--function FUNCTION] [--json]
queue dev symbols --function FUNCTION [--json]
queue dev flow --file FILE [--function FUNCTION] [--json]
queue dev flow --function FUNCTION [--json]
queue dev scratchpad help|init|import|add|task|attempt|evidence|done|reject|fail|bump-fail|list|delete|next|export|explain
```

Aliases are implementation details except where listed above. In particular, `rollback` is accepted as the user-facing equivalent of `strip`.

## Roles

`functions`, `locate`, `extract`, and `scope` are discovery operations. They must be safe to run during review and must not mutate the target file.

`symbols` and `flow` are reviewer-analysis operations. They produce structured information about symbols, strings, assignments, function ranges, callees, and control-flow nodes. They are preferred before patching when a change touches shell functions.

`patch`, `splice`, `comment`, and `strip`/`rollback` are mutating operations. They must use the dev lock, preserve backups, and leave the target syntax-valid unless an explicit no-syntax-check option is used where supported.

`diff` is a review operation against the latest dev backup.

`test` and `test result` are bounded execution-evidence operations. They use the DEV_TEST_RUNNER class and a harness root rather than ad-hoc host execution.

`scratchpad` is the authority-stamped engineering ledger. It records decisions, tasks, attempts, evidence, failures, and handover state. It must not silently self-author acceptance from test execution.

## Stable reviewer workflow

A normal maintenance workflow should be:

```text
1. Inspect with queue dev functions, locate, extract, symbols, and flow.
2. Patch with queue dev patch for function replacement or queue dev splice for bounded textual changes.
3. Review with queue dev diff and queue dev comment where useful.
4. Validate with bash -n queuebash.sh and focused tests.
5. Record attempts, evidence, failures, or decisions in queue dev scratchpad.
```

Direct editing remains acceptable for adding new documentation, fixtures, and tests, or when the dev tool cannot safely express the change. Function-level changes to `queuebash.sh` should prefer `queue dev patch` where practical.

## JSON contracts

The JSON mode of `functions`, `locate`, `extract`, `symbols`, `flow`, `patch`, `splice`, `comment`, `diff`, `strip`, `test`, and `scratchpad` is intended for tool consumers. Tests must verify that these commands return parseable JSON for representative success paths.

Schema names already emitted by the implementation include:

```text
queuebash.dev_splice_response.v1
queuebash.dev_test_result.v1
```

The JSON schema names are intentionally versioned. New incompatible shapes should use new schema names rather than silently changing old ones.

## Release discipline

When a `queue dev` command is added, removed, renamed, or substantially changes output shape, the release must update:

```text
docs/QUEUE_DEV_CONTRACT.md
docs/QUEUE_DEV_SECURITY_MODEL.md, if security semantics change
docs/QUEUE_DEV_REMOTE_REVIEW_WORKFLOW.md, if reviewer workflow changes
queue dev help output in queuebash.sh
queue-dev static/JSON/consistency tests
README.md and CHANGELOG.md
```
