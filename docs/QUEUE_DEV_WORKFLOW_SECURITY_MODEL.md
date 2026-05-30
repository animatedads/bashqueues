# queue dev workflow security model

The proposed queue dev workflow commands are governance commands.  They structure context, planning, attempts, evidence, handovers, and scratchpad lifecycle state.  They must not become a back door for arbitrary execution.

## Authority rules

- `context` is read-only.
- `think` records reviewable planning summaries under the caller authority.
- `attempt begin/end` records engineering state but does not approve code.
- `evidence record` records facts and validation outputs but does not grant acceptance.
- `handover` is read-only and summarises the working set.
- `scratchpad status set` and `scratchpad supersede` mutate lifecycle metadata only.

Acceptance remains an explicit Team Leader/reviewer authority action.  Validation output is evidence, not authority.

## Fail-closed behaviour

The command family must fail closed when it sees:

```text
unknown status
unknown item id
unknown attempt id
invalid schema version
missing replacement item for supersede
malformed JSON output request
attempt end without matching attempt begin
```

## Execution boundary

These commands must not introduce `exec`, `shell`, `bash`, `cmd`, or arbitrary command execution operations.  Evidence may record a command string that was already run by a bounded validation path, but the evidence command itself is not a runner.

## Privacy and redaction

`think` and `handover` must contain concise, reviewable engineering summaries.  They must not require storing private reasoning.  Where sensitive command output is referenced, JSON should prefer file hashes, redacted snippets, or validation log paths.


## Attempt/evidence implementation boundary

The 0.18.46 attempt/evidence commands record metadata only. They do not execute recorded commands and they do not grant acceptance authority. Validation output is evidence, not authority.
