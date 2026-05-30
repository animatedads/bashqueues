# Azure provider contracts

This package adds contract-first Microsoft Azure provider coverage for bashqueues. It is a fixture-first provider pack and does not add live Azure API calls, require credentials, provision resources, destroy resources, or modify `queuebash.sh` dispatch.

Azure provider output is normalized JSON consumed by future assets/classes/explainability. Provider helpers must return data only and must not return shell, policy code, Azure access tokens, SAS values, refresh tokens, client secrets, private keys, or full user-data/custom-script payloads.

## Schemas

- `queuebash.azure.detect.v1`
- `queuebash.azure.identity.v1`
- `queuebash.azure.region.v1`
- `queuebash.azure.compute.v1`
- `queuebash.azure.storage.v1`
- `queuebash.azure.network.v1`
- `queuebash.azure.finops.v1`
- `queuebash.azure.legal.v1`
- `queuebash.azure.explain.v1`

## Identity contract

Azure identity should prefer managed identity or federated workload identity for workers. Service principal client secrets, certificates, refresh tokens, and access tokens must not be stored in queue job files.

Required normalized fields include provider, tenant id, subscription id, principal type, auth mode, decision, source, fail_closed, and remediation hint.

## Compute/resource contract

Compute facts should describe VM size, vCPU, memory, subscription, resource group, region, tags, and maintenance/power-state posture when known from fixtures or explicitly configured facts. This package does not enforce cgroups or perform Azure VM start/stop.

## Storage/artifact contract

Blob Storage or ADLS artifact support must redact SAS tokens and signed URLs. Use evidence pointers, bounded tails, and configured account/container names. Do not log SAS query strings.

## Network contract

Network facts should record VNet, subnet, NSG, route table, private endpoint posture, and egress posture if available. Internal validation is not proof of firewall correctness; it is provider context for policy decisions.

## Legal/compliance contract

Azure legal/compliance posture should map region/sovereignty, GDPR/UK-DPA, audit logs, retention/deletion evidence, customer-managed key posture, and export-control tags. All compliance mapping in this package is `mapped_pending_validation` until validated against primary sources and accepted.

## Security hard rules

- No Azure access tokens in job files.
- No client secrets in job files.
- No SAS URLs in normal logs.
- No live Azure calls by default.
- No provisioning/destruction by default.
- Fail closed when a class requires Azure facts and provider data is missing or malformed.
