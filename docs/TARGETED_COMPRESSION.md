# Targeted log compression

Worker-side compression is targeted.

## Why

Earlier versions called:

```bash
_queue_compress_completed_logs
```

after every job. With multiple workers, that meant each worker scanned all `done/` and `failed/` jobs and could race another worker compressing the same old `.log`.

## Current behaviour

When a worker completes a job, it compresses only that job's log:

```text
done/<QID>.job   -> logs/<QID>.log.gz
failed/<QID>.job -> logs/<QID>.log.gz
```

after hooks have been appended.

Bulk compression remains available explicitly:

```bash
queue compress-logs
```

## Audit metadata

When compression succeeds, the job record gets:

```text
LOG_COMPRESSED=1
LOG_COMPRESSED_AT=...
LOG_PATH=.../<QID>.log.gz
```
