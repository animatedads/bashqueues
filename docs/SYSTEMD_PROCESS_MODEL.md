# systemd runner process model

For `RUNNER_USED=systemd`, `RUN_PID` is the `systemd-run` client/wait process.

It is **not** necessarily the payload process.

The authoritative kill/accounting target is:

```text
SYSTEMD_UNIT
```

## Kill order

For running systemd jobs, `queue cancel` and `queue kill` now use:

```text
1. systemctl --user kill --signal=<SIG> <SYSTEMD_UNIT>
2. systemctl --user stop <SYSTEMD_UNIT> for TERM
3. fallback RUN_PGID / RUN_PID signal
```

## Health

`queue health` treats a job as stale if:

```text
state directory says running/
SYSTEMD_UNIT is recorded
systemd says ActiveState=inactive/failed or SubState=dead/failed
```

This is true even if the recorded `RUN_PID` is still alive, because that PID can be the `systemd-run` client.

## Explain

`queue explain` now labels systemd `RUN_PID` as:

```text
RUN_PID: <pid> (systemd-run client)
```

and reports a warning when a job is marked running but the unit is inactive/dead.


## No PGID fallback for systemd jobs

For systemd-run jobs, queuebash does **not** fallback to `RUN_PGID` after targeting `SYSTEMD_UNIT`.

Reason:

```text
RUN_PID  = systemd-run client
RUN_PGID = may be the queue worker's process group
```

Falling back to `kill -KILL -$RUN_PGID` can kill the worker rather than the payload.

Systemd jobs are killed through:

```bash
systemctl --user kill --kill-whom=all --signal=<SIG> <SYSTEMD_UNIT>
```

with a plain `systemctl --user kill` fallback for older systemd versions.

## Stream temp cleanup

Queuebash removes stream temp files such as:

```text
.<QID>.stdout.fifo
.<QID>.stderr.fifo
.<QID>.stdout.suppressed
.<QID>.stderr.suppressed
```

when jobs complete, are cancelled, or are moved to `interrupted/` by health repair.
