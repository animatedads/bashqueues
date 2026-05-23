# bashqueues runners and containment

`bashqueues` has two execution containment models: the direct runner and the systemd runner.

The important operational fields are:

```text
RUNNER
RUNNER_USED
RUN_PID
RUN_PGID
SYSTEMD_UNIT
CPU_LIMIT
MEM_LIMIT
MAX_LOG_SIZE_BYTES
ALLOW_LARGE_LOG
```

## Runner policy

Global policy:

```bash
export QUEUEBASH_RUNNER=auto
```

Allowed values:

```text
auto      prefer systemd when available, otherwise direct
systemd   require systemd-run support
direct    bypass systemd-run and use direct/setsid
```

Per job:

```bash
queue submit heavy --runner systemd --cpu 50 --mem 4G -- rexx waiter.rex
queue submit tiny --runner direct -- echo hello
```

## Direct runner

The direct runner uses normal process execution, with `setsid` where available. This gives the payload a separate session/process group.

The job records:

```text
RUN_PID
RUN_PGID
```

Cancellation targets the process group where possible:

```bash
kill -TERM -$RUN_PGID
```

and falls back to the PID if needed.

Use the direct runner for tiny commands, compatibility testing, non-systemd hosts, containers, rescue shells, and cases where you want the fewest moving parts.

## Systemd runner

The systemd runner launches jobs as transient user services:

```bash
systemd-run --user --pipe --wait --collect \
  --working-directory="$PWD_AT_SUBMIT" \
  -p CPUQuota=50% \
  -p MemoryMax=4G \
  -- command ...
```

This gives the job a user-systemd unit and cgroup.

The job can record:

```text
SYSTEMD_UNIT=run-p...service
```

Use the systemd runner for long-running CPU-heavy work, audio/forensic processing, ffmpeg, Python workers, REXX orchestration, and jobs where cgroup metrics matter.

Inspect with:

```bash
queue metrics <job>
queue explain <job>
```

## Why this is not just `set -m`

Older shell job-control explanations often mention `set -m`, but the current `bashqueues` model does not rely on that as the core safety mechanism.

The current model is:

```text
direct runner  -> setsid + RUN_PGID
systemd runner -> transient service + SYSTEMD_UNIT + cgroup
```

Those are the pieces operators should inspect and trust.

## Logs

Running jobs write:

```text
~/.queuebash/logs/<QID>.log
```

Completed jobs are gzipped by default:

```text
~/.queuebash/logs/<QID>.log.gz
```

`queue show`, `queue tail`, and `queue explain` understand both.

## Log caps

Normal jobs are protected by a live log watchdog.

Default:

```bash
QUEUEBASH_MAX_LOG_SIZE_BYTES=52428800
```

Per job:

```bash
queue submit job --max-log-size 2G -- ./thing
```

Huge logs must be explicit:

```bash
queue submit logstorm --allow-large-log -- ./thing
```

If the cap is exceeded, the job is terminated and the job file records:

```text
LOG_OVERFLOW=1
LOG_OVERFLOW_AT=
LOG_OVERFLOW_BYTES=
LOG_OVERFLOW_CAP=
```

## Operator summary

Use:

```bash
queue explain <job>
```

for a single-page operator view covering:

```text
state
command
submit directory
runner requested/used
PID/PGID
systemd unit
CPU/memory limits
systemd metrics when available
log path/compression/cap/overflow
cancellation model
```


## Systemd MainPID note

When `systemd-run --user --pipe --wait --collect` is used, `RUN_PID` may refer to the launcher/wrapper process. The actual payload lives inside the transient service and should be inspected via:

```bash
systemctl --user show "$SYSTEMD_UNIT" -p MainPID
```

`queue pids` and `queue explain` surface this as the effective PID.


## Pending jobs

A pending or paused job has no live payload yet. `queue explain` therefore reports:

```text
used: not-started
```

and shows the runner that would be planned based on `RUNNER`, `QUEUEBASH_RUNNER`, and systemd availability.

Cancellation for pending/paused jobs only moves the job record. No process signal is sent.
