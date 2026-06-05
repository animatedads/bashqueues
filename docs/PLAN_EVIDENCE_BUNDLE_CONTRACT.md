# Queue plan evidence bundle contract

Bob24 continuation for 0.18.124.

`queue plan evidence PATH [--json]` emits `queue.plan.evidence.v1`.  It is a
review bundle over files already supplied to `queue plan`.  It separates static
plan definitions from exported runtime/job status facts and carries the same
source-contract and policy-requirement facts used by `queue plan sources`,
`queue plan status`, and `queue plan policy`.

## Boundary

The command does not collect evidence. It does not call SDKs, APIs, CLIs,
WinRM, SMB/RPC, REST, GraphQL, Kubernetes APIs, cloud providers, workflow
servers, brokers, Redis, scheduler daemons, or system logs. It does not load
credentials, read secrets, tail logs, submit jobs, mutate providers, execute
source files, or create a parallel cron scheduler. In short: no parallel cron scheduler. Cron evidence remains a
bridge to existing bashqueues cron semantics.

## Evidence groups

- `plan_definitions`: supplied static definitions such as native plans, cloud
  manifests, scheduler directives, DAGs, runbooks, service/timer units, or
  exported provider definitions.
- `runtime_job_status`: supplied job/run/status facts such as work requests,
  queue state, task state, DAG runs, pod/job status, build/deployment status,
  Python queue state, Windows Task Scheduler exports, or cloud runtime exports.

## Review use

The bundle is intended for auditors, future collectors, and automated frontends
that need a single JSON object answering:

1. What plans were supplied?
2. What runtime/job facts were supplied?
3. Which source contracts apply?
4. Which policy reviews apply?
5. Is anything unsafe or review-required?
6. What did `queue plan` explicitly not do?

Live collection remains a separate, future, policy-gated tool family.
