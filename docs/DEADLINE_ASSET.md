# Dynamic Deadline Asset

`assets.d/deadline.sh` provides deterministic deadline pressure handling for queued jobs.  It is not an AI/LLM decision maker.  It calculates slack time from a drop-dead completion time and a median historical runtime.

## Facilities

```bash
queue_class_shared_asset deadline monitor NAME drop_dead=05:00 margin_pct=15 pattern=standard
queue_class_shared_asset deadline panic NAME drop_dead=05:00 margin_pct=15 pattern=month-end
```

`deadline:monitor` always allows dispatch to continue, but it may raise the job priority while the job is still pending.

`deadline:panic` does the same calculation and, once the point of no return has been crossed, can apply only class-declared fallback asset exceptions.

## Slack calculation

The asset calculates:

```text
expected_duration = median(previous successful durations for the same JOB_NAME) + margin
point_of_no_return = drop_dead_epoch - expected_duration
slack = point_of_no_return - now
```

When slack falls below `warn_slack`, the job priority is raised to `warn_priority`.  When slack is zero or negative, the job priority is raised to `critical_priority`.

## Month-end pattern

For workload patterns such as reconciliation, billing, reporting, or forensic batch collation, `pattern=month-end` filters historical samples to completed jobs whose finish date is day 28 or later.  This avoids underestimating the runtime from ordinary daily samples.

```bash
queue_class_shared_asset deadline monitor month-end-recon \
  drop_dead=05:00 \
  pattern=month-end \
  margin_pct=20 \
  fallback_duration=180m
```

If there is not enough history, `fallback_duration` is used.  The asset fails closed if neither history nor a valid fallback is available.

## Fallback asset exceptions

Dynamic lifting of restrictions must be pre-authorised by the class, not invented by the worker at runtime.  Declare the acceptable fallback set in the class:

```bash
CLASS_DEADLINE_FALLBACK_ASSETS="snmp time:window"
queue_class_shared_asset deadline panic nightly-recon \
  drop_dead=05:00 \
  pattern=month-end \
  margin_pct=20 \
  fallback_duration=180m
queue_class_shared_asset snmp truth_ok MAINT_WINDOW
queue_class_shared_asset time window overnight weekdays=mon-fri weekday_windows=00:00-05:00
```

Place the `deadline panic` asset before the assets it may lift.  When panic mode is reached, the asset writes ordinary job-local exception records for only the assets named in `CLASS_DEADLINE_FALLBACK_ASSETS`.  Those exceptions are audited and visible in `queue explain`.

## Extra worker escalation

Priority escalation alone may not help if all currently recorded workers are busy.  A deadline asset can therefore start a bounded extra detached worker after it raises priority.  This is deliberately opt-in and should be declared by the class, because it changes queue capacity.

```bash
CLASS_DEADLINE_ALLOW_EXTRA_WORKER=1
CLASS_DEADLINE_EXTRA_WORKER_SLACK=0
CLASS_DEADLINE_MAX_EXTRA_WORKERS=1

queue_class_shared_asset deadline monitor nightly-recon \
  drop_dead=05:00 \
  pattern=month-end \
  fallback_duration=180m \
  warn_slack=3600 \
  warn_priority=50 \
  critical_priority=99 \
  start_worker=1 \
  start_worker_slack=0 \
  max_extra_workers=1
```

The asset starts an extra worker only when the queue appears saturated: running jobs are greater than or equal to recorded live workers, or a foreground worker is running jobs but no detached worker PID files exist.  It writes `DEADLINE_EXTRA_WORKER_*` fields into the job record and creates worker PID files under `$QUEUEBASH_ROOT/workers/`.

This does not bypass class/global resource claims.  It only adds dispatch capacity so that the newly critical job can be picked up as soon as the normal queue rules allow it.

## Parameters

| Parameter | Meaning |
| --- | --- |
| `drop_dead=05:00` | Required completion deadline. Supports `HH:MM`, epoch seconds, or a date parseable by `date -d`. |
| `margin_pct=15` | Percentage added to the median runtime. |
| `pattern=standard` | Uses all successful history for the same job name. |
| `pattern=month-end` | Uses only successful history completing on day 28 or later. |
| `warn_slack=3600` | Seconds of remaining slack at which to raise to warning priority. |
| `warn_priority=50` | Priority used in the warning zone. |
| `critical_priority=99` | Priority used after the point of no return. |
| `min_samples=1` | Minimum historical samples before trusting median history. |
| `fallback_duration=180m` | Deterministic runtime estimate when history is insufficient. |
| `panic_assets="..."` | Per-asset fallback list. Prefer `CLASS_DEADLINE_FALLBACK_ASSETS` in the class. |
| `start_worker=1` | Opt-in: after priority escalation, start a bounded extra detached worker if the queue appears saturated. |
| `start_worker_slack=0` | Start the extra worker only when slack is at or below this number of seconds. |
| `max_extra_workers=1` | Queue-level cap for deadline-started extra workers. |

## Test-only parameter

`now_epoch=SECONDS` is accepted for regression tests and simulations.  Do not use it in production classes.
