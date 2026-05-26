# Cleared job audit listing

`queue cleared` lists jobs that have passed the queuebash dispatch-clearance boundary.
A job is marked cleared after it has passed execution policy, class/resource checks,
mandatory policy assets, dynamic preflight, and global claims, and immediately before
payload launch.

This is different from `queue list`: it is an audit view of jobs that were allowed to
run, not merely jobs in a particular filesystem state.

## Commands

```bash
queue cleared
queue cleared --json
queue cleared --state running,done,failed --limit 50
queue cleared --since "2026-05-26 09:00"
queue clearance list --json
queue audit cleared --json
```

## Job metadata

Cleared jobs are stamped with fields such as:

```bash
JOB_CLEARED=1
JOB_CLEARED_AT=...
JOB_CLEARED_BY=...
JOB_CLEARED_CLASS=...
JOB_CLEARED_POLICY_STATEMENT=...
JOB_CLEARED_STAGE=execution_policy,class_assets,mandatory_policy_assets,dynamic_preflight,global_claims
```

When available, the stamp also records sandbox/seccomp/runtime-cap policy names,
security exemption or authorisation information, and jurisdiction/classification
metadata.

## JSON output

`queue cleared --json` returns a `cleared` array suitable for audit automation.
Each item includes the QID, job name, state, class, clearance time, policy statement,
security summary, governance summary, timestamps, return code, command line, and job file.

`queue status JOB --json` also includes a compact `clearance` object for single-job
lifecycle checks.
