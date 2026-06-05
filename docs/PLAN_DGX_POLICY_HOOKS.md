# queue plan DGX cloud and workflow policy hooks

Bob24 treats DGX/GPU plans as strong policy material, not just resource sizing.
DGX estates often combine expensive accelerators, cloud placement, model/data
movement, workflow orchestration, identity delegation and gateway exposure.  A
`queue plan` adapter that sees DGX/GPU hints must therefore add an explicit
policy hook before any future apply path can proceed.

## Detection hints

The scan/build helper records `DGX_CLOUD_WORKFLOW_POLICY_REVIEW` when it sees
any of these non-secret source facts:

- `dgx`
- `nvidia.com/gpu`
- GPU resource names or GPU class hints

It also records `CLOUD_WORKFLOW_POLICY_REVIEW` when cloud-provider markers and
workflow/pipeline/DAG markers appear together.

## Boundary

The hook is advisory/gating metadata in this patchset.  It does not contact DGX
systems, cloud APIs, model registries or workflow engines.  It does not infer
secret values.  It does not submit work.

Future apply paths must treat these hooks as approval gates and must reuse the
existing bashqueues policy, identity, asset, gateway, cron and workflow safety
models.

## 0.18.118 policy requirements view

The continuation release exposes these hooks through:

```sh
queue plan policy PATH [--json]
```

The JSON schema is `queue.plan.policy.v1`.  DGX/GPU evidence is also copied into `plan.policy_requirements` inside `queue.control_plan.v1`, so future apply paths can consume it without scraping human reports.

DGX requirements reference the existing `gpu-cloud` policy family, including cost/FinOps, network, object-storage and region policy fixtures.  Cloud-workflow requirements reference the cloud provisioning/lifecycle dry-run contracts.  Both are lifecycle-safe: `queue plan` may describe a handoff boundary, but it must not mutate provider lifecycle state.
