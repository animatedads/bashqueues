# Edge cloud provider contracts

This package defines fixture-first provider contracts for edge compute and edge application platforms:

- Cloudflare Workers
- Fastly Compute@Edge
- Fly.io

The package is contract-only. It does not call live provider APIs, does not require provider credentials for default tests, does not deploy edge applications, and does not wire provider logic into `queuebash.sh` dispatch.

## Normalized schemas

Each provider fixture/helper output uses provider-family scoped schemas:

```text
queuebash.edge_cloud.cloudflare.detect.v1
queuebash.edge_cloud.cloudflare.identity.v1
queuebash.edge_cloud.cloudflare.region.v1
queuebash.edge_cloud.cloudflare.edge_runtime.v1
queuebash.edge_cloud.cloudflare.storage.v1
queuebash.edge_cloud.cloudflare.network.v1
queuebash.edge_cloud.cloudflare.finops.v1
queuebash.edge_cloud.cloudflare.legal.v1
```

Equivalent schema names exist for `fastly` and `flyio`.

## Provider helper

```bash
providers.d/edge_cloud/edge_cloud_provider.sh PROVIDER detect
providers.d/edge_cloud/edge_cloud_provider.sh PROVIDER identity explain
providers.d/edge_cloud/edge_cloud_provider.sh PROVIDER region explain
providers.d/edge_cloud/edge_cloud_provider.sh PROVIDER edge-runtime explain
providers.d/edge_cloud/edge_cloud_provider.sh PROVIDER storage explain
providers.d/edge_cloud/edge_cloud_provider.sh PROVIDER network explain
providers.d/edge_cloud/edge_cloud_provider.sh PROVIDER finops explain
providers.d/edge_cloud/edge_cloud_provider.sh PROVIDER legal explain
```

Default mode is fixture-only through `QUEUEBASH_EDGE_CLOUD_FIXTURE_DIR`.

Live provider checks are intentionally not implemented in this contract package.

## Security rules

- Do not store provider API tokens in job files.
- Do not store deployment secrets, environment secrets, KV/database credentials, TLS private keys, or signed URLs in the registry or scratchpad.
- Treat edge deployment logs and cache keys as potentially sensitive.
- Treat customer-data residency and cache/log retention as explicit class criteria.
- Fail closed for classes requiring an edge provider decision when the provider cannot return normalized JSON.
