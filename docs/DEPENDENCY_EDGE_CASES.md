# bashqueues dependency edge cases

`bashqueues` supports two orchestration styles:

```text
push-style hooks       --on-success / --on-failure / --on-retry-failure
pull-style dependency  --after-success / --after / --depends-on
```

The dependency implementation is pull-style: pending jobs are skipped until their dependency conditions are satisfied.

## Retroactive satisfaction

If a dependency is already in `done/`, a newly submitted dependent job can run immediately.

## Failed parent blocks child

If a parent dependency is in `failed/`, `interrupted/`, `cancelled/`, or `deleted/`, the child remains pending. This prevents downstream cascade failures.

## Duplicate ancestor names

A name dependency means:

```text
any successful job with that exact JOB_NAME
```

If strict sequencing matters, use an exact QID dependency instead.

## QID dependencies

A QID dependency means:

```text
this exact ancestor job
```

Use this when duplicate job names exist and you need strict lineage.

## Circular dependencies

Cycles are safe but not yet generally rejected at submit time. Cyclic jobs remain pending. Use:

```bash
queue waiting
queue deps <job>
```

to diagnose.

Exact self-dependencies are rejected at submit time.

## Fan-in

Multiple `--after-success` arguments mean all dependencies must be satisfied.

```bash
queue submit final \
  --after-success branch_1 \
  --after-success branch_2 \
  --after-success branch_3 \
  -- ./merge.sh
```

## Test script

Run:

```bash
QUEUEBASH_ALLOW_NONINTERACTIVE=1 tests/dependency_edge_cases.sh
```

This is a diagnostic edge-case test, not part of the fast regression suite, because it deliberately creates blocked/cyclic pending jobs.
