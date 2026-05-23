# Cancellation races

A worker can still be waiting for a payload when an operator runs:

```bash
queue kill <job>
queue cancel <job>
```

The operator command moves:

```text
running/<QID>.job -> cancelled/<QID>.job
```

The payload then exits because it was signalled. The worker sees a non-zero return code from the payload runner, but the running job record has already been moved.

Correct behaviour:

```text
worker prints cancelled, not failed
worker does not run ON_FAILURE
worker does not move the job to failed
worker records worker_observed_cancelled in events.jsonl
```

This preserves audit meaning:

```text
failed    = program/runner failure
cancelled = operator action
```
