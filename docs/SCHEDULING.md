# bashqueues scheduling

`bashqueues` supports simple one-shot scheduled submission.

## Submit after a delay

```bash
queue submit-in 10m publish_later -- bash publish_to_github.sh
queue submit-in 2h ingest_later -- python forensic_helper.py --ingest ./day2 --yaml tblisi.yaml
```

Supported delay units:

```text
s seconds
m minutes
h hours
d days
w weeks
```

Compound delays are supported:

```bash
queue submit-in 1h30m job -- ./thing
```

A plain integer is seconds:

```bash
queue submit-in 60 job -- ./thing
```

## Submit at a time

```bash
queue submit-at 23:30 night_job -- ./nightly.sh
queue submit-at "2026-05-22 23:30" night_job -- ./nightly.sh
```

`HH:MM` means today at that time, or tomorrow if the time has already passed.

## Worker behaviour

Scheduled jobs remain in `pending/`.

Workers skip them until their `NOT_BEFORE_EPOCH` is due.

## Metadata

```text
NOT_BEFORE_EPOCH=<epoch>
SCHEDULE_LABEL=<human submit string>
```

Retry jobs also have `RETRY_NOT_BEFORE_EPOCH`. The effective not-before time is the later of the two.

## Inspecting scheduled jobs

```bash
queue scheduled
queue schedule
queue explain <job>
```

Inside `queuemgr`:

```text
sched    show scheduled pending jobs
```

## Interaction with dependencies

Both schedule and dependencies must be satisfied before a pending job can run.
