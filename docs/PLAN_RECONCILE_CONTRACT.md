# Queue Plan Reconcile Contract

`queue plan reconcile PATH [--json]` is the Bob24 supplied-evidence bridge between
plan definitions and runtime/job status facts.

It answers a narrow question:

```text
Given the files supplied to queue plan, which plan definitions appear to have
related exported job/status evidence, which plans have no supplied job evidence,
and which job/status facts appear orphaned?
```

## Boundary

Reconcile is advisory and no-live.

It does not:

- call cloud SDKs, APIs or CLIs;
- open WinRM, SMB, RPC, REST, GraphQL or Kubernetes API connections;
- load credentials or secrets;
- tail logs;
- submit jobs;
- mutate providers;
- execute source files; or
- create a parallel cron scheduler.

Standing phrases for static guards: no SDK/API/CLI calls; no parallel cron scheduler.

Cron evidence continues to bridge to existing bashqueues cron support.

## Inputs

Inputs are the same files accepted by the rest of `queue plan`:

- native bashqueues plans;
- Kubernetes, cloud and HPC definitions;
- workflow definitions;
- exported runtime/job/status facts;
- evidence bundles supplied by future external collectors.

## Output schema

JSON output uses:

```text
queue.plan.reconcile.v1
```

The output contains:

- `summary`: plan/job/correlation counts;
- `correlations`: best-effort matches between a plan file and a runtime/status file;
- `unmatched_plan_definitions`: plans with no supplied runtime evidence;
- `orphan_runtime_job_status`: runtime/job facts with no supplied plan definition;
- `policy_requirements`: inherited policy hooks;
- `review`: advisory status and safe-to-apply refusal;
- `attestations`: no-live guarantees.

## Matching model

The current matcher is deliberately conservative and review-oriented. It may use:

- provider match, for example AWS-to-AWS or Azure-to-Azure;
- adapter family match, for example workflow-to-workflow;
- token overlap from paths, object names and inferred class names.

A correlation is never proof of identity. It is a reviewer hint.

Future live collectors, if ever added, must be separate policy-gated tools and
must not be hidden inside `queue plan reconcile`.
