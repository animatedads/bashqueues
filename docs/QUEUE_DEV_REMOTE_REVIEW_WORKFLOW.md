# queue dev remote review workflow

This document describes the safe remote-review pattern for using `queue dev` through a future remote queue service or an AI-assisted reviewer. It does not introduce a remote shell and does not broaden the current remote management surface.

## Principle

Remote development must be operation-based, not command-string-based. A reviewer asks for specific `queue dev` facts or applies a bounded patch through an approved operation. The service enforces ACLs, workspace scope, file scope, timeouts, audit logging, and JSON result limits.

## Recommended operation sequence

```text
1. dev.functions on the target file to identify candidate functions.
2. dev.extract on the function being discussed.
3. dev.symbols and dev.flow for dependency/control-flow review.
4. dev.patch for function-level replacement, or dev.splice for bounded text insert/replace.
5. dev.diff for review against the latest backup.
6. dev.test for a bounded validation command.
7. dev.scratchpad to record reviewer notes, attempts, evidence, or handover.
```

For simple documentation and fixture additions, direct repository file writes may still be simpler, but queuebash function edits should prefer `dev.patch` where practical.

## Denied remote operations

A remote queue/dev service must deny operation names or user input that attempts to become:

```text
shell
exec
bash
sh
cmd
command
run
kill
cancel
write-anywhere
```

The only acceptable execution path for development validation is the bounded `dev.test` contract.

## Audit fields

A remote review implementation should audit at least:

```text
subject/client identity
operation name
provider/service name
workspace or repository scope
target file and function, if applicable
request hash or redacted request summary
policy decision
redaction decision
result status
output size and truncation flag
failure reason
correlation id
```

Audit logs should avoid full secrets, full patches containing credentials, and unbounded command output by default.

## Relationship to future Grid FinOps and OT/ICS work

Grid FinOps and OT/ICS provider contracts should follow the same discipline: provider facts first, policy gates second, audited dry-runs third, and live mutation only much later under explicit governance. `queue dev` is the development-control example for that broader provider discipline.
