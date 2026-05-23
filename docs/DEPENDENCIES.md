# bashqueues dependencies

Dependencies let a pending job wait for another job to finish successfully.

The first supported dependency mode is intentionally conservative:

```bash
--after-success <qid-or-exact-job-name>
```

Aliases:

```bash
--after <qid-or-exact-job-name>
--depends-on <qid-or-exact-job-name>
```

## Example

```bash
queue submit ingest_day1 -- python forensic_helper.py --ingest day1 --yaml tblisi.yaml

queue submit enhance_day1 \
  --after-success ingest_day1 \
  -- python dual_feed_enhance_v8.py --yaml tblisi.yaml --start ...
```

`enhance_day1` remains in `pending/` until at least one job named `ingest_day1` is in `done/`.

## Metadata

The dependency is stored inside the job file:

```text
DEPENDS_AFTER_SUCCESS=ingest_day1
```

This keeps the design filesystem-native and inspectable.

## Worker behaviour

Workers skip pending jobs whose dependencies are not satisfied.

This means:

```text
pending job with satisfied deps     -> eligible to run
pending job waiting on deps         -> skipped
pending job whose dep failed        -> remains pending but is reported by queue deps / queue waiting
```

## Inspecting dependencies

```bash
queue deps <job>
queue dependencies <job>
queue waiting
```

Inside `queuemgr`:

```text
dep <job>  show dependencies
wait       show pending jobs waiting on dependencies
```

## Current limitations

Only success dependencies are implemented.

Future modes may include:

```text
--after-any
--after-failure
```

but `--after-success` is the safest and covers the main pipeline case.


## Testing dependencies

Run:

```bash
QUEUEBASH_ALLOW_NONINTERACTIVE=1 tests/after_success.sh
```

The test covers:

```text
child waits for missing parent
parent success releases child
parent failure blocks child
QID dependency
multiple dependencies
queue deps
queue waiting
```


## Self-dependencies

A job cannot depend on itself by exact job name.

This is rejected at submit time:

```bash
queue submit self_dep --after-success self_dep -- echo loop
```

Result:

```text
queue submit: job cannot depend on itself: self_dep
```

This prevents a silent permanent pending job.


## Safe failure semantics

If a dependency fails, is cancelled, is interrupted, or is deleted, dependent jobs remain in `pending/`.

This is intentional. Queuebash prevents downstream cascade failures.

Use:

```bash
queue waiting
queue deps <job>
```

to diagnose blocked jobs.


## Cycles

General dependency cycles are safe but not yet rejected at submit time.

For example, if `a` waits on `b` and `b` waits on `a`, both jobs remain pending. Use:

```bash
queue waiting
```

to diagnose cyclic or otherwise unsatisfied dependencies.
