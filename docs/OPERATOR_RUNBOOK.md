# Queuebash operator runbook

This runbook is for operators running queuebash in dev, test, or controlled enterprise pilot environments. It is not a live-hospital production clearance document. For hospital-style sensitive data environments, use this document together with `docs/REGULATED_SERVICE_RUNBOOK.md`, `docs/HOSPITAL_LIVE_SAFE_MODE.md`, and `docs/RUPERT_ENTERPRISE_PILOT_EVIDENCE.md`.

## First rule: know which queue command you are using

Before system installation, `queue` is a shell function available only after sourcing `queuebash.sh` in the current shell:

```bash
source ./queuebash.sh
queue version
```

After system installation, `/usr/local/bin/queue` is the installed wrapper intended for scripts, cron, `timeout`, CI, and systemd. Operators should not assume a sourced shell function exists in non-interactive automation.

```bash
command -v queue
queue version --json
```

## Policy-root preflight

The active system policy root is `/etc/queuebash/policies.d`. The legacy spelling `/etc/bashqueues/policies.d` must not silently become active.

Run these before changing system policy:

```bash
queue policy paths --json
queue policy status --json
./install-system.sh --dryrun
bin/queue-policy-wizard --scope system --dryrun --non-interactive --json
bash tests/policy_namespace_consistency_static.sh
```

Expected posture:

```text
active_policy_root=/etc/queuebash/policies.d
legacy_policy_root=/etc/bashqueues/policies.d
legacy_root_active=false
```

If any command points to the legacy tree as active, stop and fix the namespace before approving live or maintenance work.

## Enterprise profile preflight

Enterprise profiles under `policies.d/enterprise/*.env.example` are intentionally inert examples. Do not source or install them directly without site-specific review.

Safe validation commands:

```bash
queue enterprise list-profiles --json
queue enterprise validate-profile hospital-live-readonly-default --json
queue enterprise validate-profile hospital-live-approved-maintenance-default --json
```

Safe validation must report that examples are not active and do not modify the system:

```text
example=true
active=false
activation_supported=false
system_modified=false
live_clearance_granted=false
```

## Maintenance evidence preflight

Before a controlled maintenance pilot, validate a maintenance request as evidence only:

```bash
queue enterprise verify-maintenance --request examples/enterprise/maintenance-request.example.json --json
```

A safe evidence verifier may say whether the request is structurally acceptable, but it must not grant live clearance or modify the system.

## Allowed early pilot scope

Dev/test and controlled admin pilots may use:

```text
queue list/show/status/stats/workers/events --json
queue policy paths/status --json
queue enterprise list-profiles/validate-profile/verify-maintenance --json
queue plan scan/explain/build/validate for inert plan artifacts
read-only audit/reporting checks
backup verification and deployment preflight
```

## Not allowed without explicit future clearance

Do not use queuebash for broad live hospital execution. Do not enable mutation by accident. Do not treat templates as active policy. Do not grant live clearance from an example profile. Do not let an AI/provider gate execute generated commands.

## When a job appears stuck in running

For any job that appears to be running but did not start cleanly or has no live process/unit evidence:

```bash
queue show JOB
queue explain JOB
queue health
queue health --fix
queue history JOB --json
```

If a systemd-backed job is involved, check the recorded unit when present:

```bash
queue unit JOB
```

A job that never started should be moved to a clear failure/interrupted state by health tooling or operator action; it should not be left ambiguous in `running`.

## Incident notes

Record the exact command, JSON output, policy root, queue root, job ID, log path, and operator/ticket reference. Do not overclaim full-suite validation from a sandbox run; record bounded test evidence only.
