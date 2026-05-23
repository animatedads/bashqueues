# bashqueues logs

## Combined stdout/stderr

By default, queuebash combines stdout and stderr into a single chronological transcript:

```text
~/.queuebash/logs/<QID>.log
~/.queuebash/logs/<QID>.log.gz
```

The worker uses:

```bash
>> "$log" 2>&1
```

## Compression

Completed logs are gzipped automatically when:

```bash
QUEUEBASH_GZIP_LOGS=1
```

Manual compression:

```bash
queue compress-logs
queue gzip-logs
```

## Cleaning logs

Preview:

```bash
queue clean-logs --dryrun
```

Delete logs older than 30 days:

```bash
queue clean-logs --older-than 30d --force
```

Clean by state:

```bash
queue clean-logs --state done --older-than 7d --force
queue clean-logs --state failed --older-than 14d --force
queue clean-logs --state cancelled --force
queue clean-logs --orphan --force
```

Safe defaults:

```text
without --force, clean-logs previews only
running logs are never deleted unless --include-running is used
without --all/--state, only done/failed/interrupted/cancelled/deleted/orphan are eligible
```

`queue clear done` removes job records. `queue clean-logs` removes transcript files. They are intentionally separate.


## Log cleanup audit trail

When `queue clean-logs --force` deletes a log that belongs to a known job, queuebash appends audit metadata to the job file before deletion:

```bash
LOG_CLEANED=1
LOG_CLEANED_AT=...
LOG_CLEANED_PATH=...
LOG_CLEANED_BYTES=...
```

It also writes a structured event:

```text
event=log_cleaned
```

to:

```text
~/.queuebash/events.jsonl
```

This means the bulky transcript can be deleted while the job record still shows when cleanup happened and how large the removed log was.


## stderr-only overflow policy

Default:

```bash
QUEUEBASH_LOG_OVERFLOW_POLICY=stderr-only
```

Behaviour:

```text
before first cap:     log stdout + stderr
after first cap:      suppress stdout, keep logging stderr
after second cap:     suppress stderr too
always:               keep draining both streams so the child process does not see a closed pipe
```

Per job:

```bash
queue submit noisy --max-log-size 50M --log-overflow stderr-only -- ./noisy.sh
queue submit strict --max-log-size 50M --log-overflow kill -- ./noisy.sh
queue submit huge --allow-large-log -- ./intentional-big-log.sh
```
