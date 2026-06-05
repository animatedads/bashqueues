# Queue plan control model

Bob24 defines `queue plan` as the universal plan-ingestion surface. A source plan may be native bashqueues YAML, Kubernetes YAML, cloud batch JSON, HPC scheduler directives, Nomad HCL, CI/CD YAML, cron, systemd, a common operational script, or another supported declarative/operational format. The operator workflow must remain the same for every supported source:

```text
queue plan scan PATH
queue plan explain PATH
queue plan build PATH --output DIR
queue plan validate DIR
queue plan apply DIR --dry-run
```

The adapter changes; the operator experience does not.

## Core rule

A source file is an operational intent document, not merely a job. It may imply classes, assets, identities, secrets, network controls, gateways, schedules, dependencies, resource caps, approval gates, and unsafe conditions.

Bob24 adapters must therefore normalize source-specific declarations into `queue.control_plan.v1` before any staged bashqueues controls are emitted.

## Normalized objects

`queue.control_plan.v1` contains these object families:

- `classes`: candidate bashqueues operating classes, including concurrency, priority, placement, runner and policy overlays.
- `restrictions`: network, filesystem, user, seccomp, capability, secret, identity and cloud-permission restrictions that must exist before work is run.
- `assets`: CPU, memory, disk, GPU, network, object store, database, licence, subnet, identity and gateway assets.
- `gateways`: listener/route/exposure declarations, including TLS, source restrictions and destination class/job/service.
- `identities`: service accounts, IAM roles, managed identities, scheduler accounts, projects, accounts and QOS bindings.
- `secrets`: secret references only; adapters must not import or expose secret values.
- `job_templates`: source-derived job/task templates, commands, images, arguments, environment references, schedules, retries and timeouts.
- `workflows`: node/edge graph, fanout, joins, failure policy and artifact handoff.
- `dependencies`: explicit order constraints between assets, restrictions, identities, classes, gateways and jobs.
- `approval_gates`: manual or policy-gated conditions before staging or live apply.
- `analysis`: source provenance, adapter confidence, warnings, unsupported controls, review requirements and refusal reasons.

## Planning order

The common planner must order controls before runnable work:

```text
parse source
classify operational intent
build dependency graph
infer restrictions
infer assets/identities/secrets/gateways
create class candidates
create job/workflow candidates
stage generated controls
explain warnings/refusals/approval gates
```

This deliberately differs from systems that apply a manifest and wait for external controllers to reconcile. bashqueues must be able to explain and stage a safe operating model before jobs are allowed into that model.

## Fail-closed posture

Adapters must not silently convert privileged, public, destructive, identity-expanding or ambiguous controls into runnable work. The minimum states are:

```text
accepted
accepted_with_warnings
needs_review
unsupported
unsafe_refused
```

Unknown fields should be preserved in provenance/metadata where practical. Unknown unsafe semantics must be refused or marked `needs_review`, not ignored.
## Script-derived plans

Common operational scripts are also plan candidates when they contain recognizable deterministic behaviour. The script adapter should normalize observed behaviour into the same object families: classes, restrictions, assets, identities, dependencies, job templates and approval gates.

Script-derived plans are lower confidence than native declarative formats. They must be static-only and fail closed: the adapter may infer that a script looks like a backup, migration, rollout, test, maintenance or cloud-control operation, but dynamic code, command generation, privilege escalation, secret exposure, broad deletion or public/network mutation must become review/refusal evidence.

The planner should treat script order as a candidate dependency graph: pre-flight checks before tool use, directory creation before writes, database dump before upload, migration before restart, cleanup traps as failure-policy hints, and bounded loops as fanout candidates.
