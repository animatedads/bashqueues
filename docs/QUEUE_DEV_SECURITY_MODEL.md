# queue dev security model

`queue dev` is powerful because it can inspect and mutate source files. The security model is therefore simple: every mutating operation must be explicit, local, auditable, lock-protected, and reversible by backup unless the operation is a deliberately read-only inspection.

## Boundaries

`queue dev` is not a generic shell execution API. It must not grow `exec`, `shell`, `bash`, `cmd`, or arbitrary host-command subcommands. Execution evidence belongs under `queue dev test`, which routes through the bounded DEV_TEST_RUNNER harness.

Remote service integrations must expose `queue dev` only as named policy-gated operations such as:

```text
dev.functions
dev.locate
dev.extract
dev.symbols
dev.flow
dev.patch
dev.splice
dev.comment
dev.diff
dev.test
dev.scratchpad
```

They must not expose a generic remote shell or a write-anywhere file API.

## Mutating operations

The mutating operations are:

```text
queue dev patch
queue dev splice
queue dev comment
queue dev strip
queue dev rollback
```

These operations must use the dev lock before changing a file, create or use backups where appropriate, and avoid leaving a partially written target. For shell source changes, the normal path must syntax-check the target before replacing it.

## Non-mutating operations

The non-mutating operations are:

```text
queue dev functions
queue dev locate
queue dev extract
queue dev scope
queue dev symbols
queue dev flow
queue dev diff
queue dev test result
queue dev scratchpad list/export/explain/next
```

`queue dev test` creates isolated harness state and queue jobs by design, but it must not directly mutate project source.

## Scratchpad authority

The scratchpad is an engineering ledger, not an automatic approval engine. Test execution may produce evidence, but it must not silently create an acceptance decision. Acceptance, rejection, and task-authority records must be explicit and authority-tagged.

## Fail-closed expectations

A `queue dev` operation should fail rather than guessing when:

```text
a function name is invalid
a target file is missing
a function cannot be located
a lock cannot be acquired
a backup cannot be verified
a JSON-emitting path cannot construct valid JSON
a syntax check fails on a normal mutating path
```

Failure messages should be bounded and should not dump secrets from the environment.
