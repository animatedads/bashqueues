# 0.18.55 BOB10 cloud infrastructure helper parity for EU sovereign and APAC/China

This package extends the `cloud_infra` lifecycle-helper contract to provider families that were already mapped as cloud/provider contract packs but did not yet have equivalent helper rails.

The new helpers are fixture-first and dry-run/status only. They do **not** perform live provider API calls, require credentials, create resources, destroy resources, or change queue dispatch behaviour.

## Added helper rails

EU sovereign provider families:

- `ovh_vm` through `providers.d/cloud_infra/ovh_vm_stack.sh`
- `scaleway_instance` through `providers.d/cloud_infra/scaleway_instance_stack.sh`
- `hetzner_cloud` through `providers.d/cloud_infra/hetzner_cloud_stack.sh`
- `otc_ecs` through `providers.d/cloud_infra/otc_ecs_stack.sh`

APAC/China provider families:

- `alibaba_ecs` through `providers.d/cloud_infra/alibaba_ecs_stack.sh`
- `tencent_cvm` through `providers.d/cloud_infra/tencent_cvm_stack.sh`
- `huawei_ecs` through `providers.d/cloud_infra/huawei_ecs_stack.sh`

## Boundary

These helpers only answer lifecycle planning/status questions through normalized JSON:

```text
registry -> provider helper -> queuebash.cloud_infra.action.v1
```

They are not scheduling logic. They are not cloud-resource claims. They are not provisioning apply. They must remain separate from `cloud_resource`, `cloud_provision`, and queue dispatch.

## Live mutation

Live mutation remains unavailable for this provider-family parity package. The helpers return `dry_run` for `plan-*` and `status` actions and deny direct `start`/`stop` attempts unless a later package implements audited live gates.

Provider credentials alone must never become sufficient authority.
