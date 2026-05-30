# Cloud Provisioning Dry-Run Lifecycle Integration

`cloud_provision` remains a Bob10 work-order layer. In this release it can ask the adjacent `cloud_infra` helper layer for a **dry-run lifecycle plan** for a named service/template.

The flow is:

```text
cloud_provision plan TEMPLATE
  -> policy gates
  -> lifecycle-plan TEMPLATE
  -> cloud_infra plan SERVICE start
  -> normalized dry-run lifecycle evidence
```

This is not live provisioning. The integration is deliberately limited to dry-run evidence so provider credentials are not required and cloud state is not mutated.

## Boundary

- `cloud_resource` owns inventory, claims, releases, heartbeat, reconcile, provenance, and policy-consumable facts.
- `cloud_infra` owns gated lifecycle start/stop/status helper rails.
- `cloud_provision` owns named templates, plan/validate/explain/dry-run workflow, lifecycle dry-run evidence, and registry handoff previews.
- Queue dispatch must not directly call cloud provider lifecycle operations.

## Commands

```bash
providers.d/cloud_provision/cloud_provision.sh lifecycle-plan aws-ec2-gdpr --json
providers.d/cloud_provision/cloud_provision.sh registry-preview aws-ec2-gdpr --json
```

`lifecycle-plan` emits `queuebash.cloud_provision.lifecycle_plan.v1`.
`registry-preview` emits `queuebash.cloud_provision.registry_preview.v1`.

## Live gate

Live apply remains absent from this package. Future live provisioning must require explicit live enablement, provider policy permission, template allowlist, authority/change-ticket or reason, legal/data-protection/export-control gates, cost gates, audit availability, and normalized evidence. Provider credentials alone must never be sufficient.
