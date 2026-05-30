# Queue Dev Validate and Scope Gates

`queue dev validate` and `queue dev scope-check` are bounded reporting gates for AI-assisted development. They are deliberately not acceptance commands: they do not mutate the scratchpad, create reviewer decisions, or mark work accepted.

## `queue dev validate`

```bash
queue dev validate [--json] [--quick] [--timeout SEC] [--file FILE...]
```

The command runs a small, bounded validation set from the current working tree. It uses `bin/queue-dev-timeout` when present so every Bob gets the same non-interactive environment and timeout behaviour.

Default checks include:

```text
bash -n queuebash.sh
tests/dev_qbtest_static.sh
tests/dev_qbtest_json_contract_static.py
queue dev test qbtest --file queuebash.sh --function _queue_now
tests/dev_timeout_helper_smoke.sh
tests/queue_dev_contract_static.sh
```

`--quick` omits the slower optional smoke/static checks. `--file FILE` adds file-specific checks: Bash syntax for shell files, Python compile checks for Python files, and QBTEST execution when the file carries embedded `QBTEST:BEGIN` blocks.

JSON output uses:

```text
queuebash.dev_validate_result.v1
```

## `queue dev scope-check`

```bash
queue dev scope-check [--json] [--allow GLOB...] [--deny GLOB...] [--file FILE...]
```

The command checks a set of changed files against simple shell globs. When `--file` is omitted, it reads changed entries from `.queuebash/dev/file_registry.json`.

Examples:

```bash
queue dev scope-check --file queuebash.sh --allow 'queuebash.sh' --json
queue dev scope-check --file providers.d/ask/groq.sh --deny 'providers.d/ask/*'
```

JSON output uses:

```text
queuebash.dev_scope_check_result.v1
```

## Authority boundary

These commands are gate/report helpers only. A passing result is evidence for a reviewer, not a reviewer decision. Acceptance still belongs to the Architect, Team Leader, or reviewer authority path.
