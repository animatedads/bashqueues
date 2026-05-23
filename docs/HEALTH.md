# bashqueues health and integrity

`queue health` is an operator-focused integrity check for the filesystem-backed queue.

## Basic check

```bash
queue health
```

Checks:

```text
queue root exists and is writable
state directories exist
logs and events.jsonl are writable
free disk space
free inode count
gzip availability
setsid availability
systemd-run availability
malformed job files
stale running jobs
blocked/missing dependencies
```

## Safe repair

```bash
queue health --fix
```

Safe repairs:

```text
create missing state/log/worker directories
remove dead worker pid files
move definitely stale running jobs to interrupted/
```

`--fix` does not delete job records or logs.

Note: the main `queue` dispatcher normally runs `_queue_init` before commands, so missing state directories may already be recreated before `health` prints its report.

## Deep checks

```bash
queue health --deep
```

Adds heavier diagnostic checks:

```text
self-cycle warnings
2-node cycle warnings
```

General cycle detection is intentionally conservative. Cyclic dependencies are safe because jobs remain pending, but `queue waiting`, `queue deps`, and `queue health --deep` help diagnose them.

## Stale running jobs

For direct jobs, health checks `RUN_PID`.

For systemd jobs, health prefers the recorded `SYSTEMD_UNIT` and asks user-systemd whether it is still active.

If a running job is definitely stale and `--fix` is supplied, it is moved:

```text
running/ -> interrupted/
```

and annotated with:

```text
INTERRUPTED_AT
INTERRUPTED_REASON
INTERRUPTED_FROM
```
