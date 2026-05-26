# Cloud sovereignty and FinOps assets

This release adds cloud routing gates that remain queuebash-native: workers evaluate local preflight assets, and jobs remain pending until a worker satisfies the declared legal, identity, and cost constraints.

## Policy

Legal framework mappings are shipped as both:

- `policies.d/legal_framework.env`
- `policies.d/legal-framework/default.env`

The two paths deliberately contain the same defaults so sites can use either the simple legacy-style file name or the policy-directory style used elsewhere in bashqueues.

Example:

```bash
LEGAL_FRAMEWORK_GDPR_REGIONS="eu-central-1,eu-west-3,eu-west-1,eu-west-2,europe-west3,europe-west9,europe-west1,europe-west2,germanywestcentral,francecentral,westeurope,northeurope,uksouth"
LEGAL_FRAMEWORK_UK_DPA_REGIONS="eu-west-2,europe-west2,uksouth,ukwest"
```

## Worker identity

Workers should export their cloud location at boot or via systemd environment:

```bash
QUEUEBASH_CLOUD_REGION="europe-west2"
QUEUEBASH_CLOUD_INSTANCE_TYPE="e2-standard-4"
```

## Assets

### `sovereign:framework_allowed`

```bash
queue_class_shared_asset sovereign framework_allowed "GDPR"
```

Loads the legal-framework policy and checks whether `QUEUEBASH_CLOUD_REGION` is allowed for that framework.

### `sovereign:region_in`

```bash
queue_class_shared_asset sovereign region_in "eu-west-2,europe-west2,uksouth"
```

Direct allow-list check without a named framework.

### `finops:spot_price_below`

```bash
queue_class_shared_asset finops spot_price_below "0.08" instance_type="m5.large"
```

Reads a local cache file such as:

```text
/var/tmp/queuebash_pricing_eu-west-2_m5.large.txt
```

The file should contain a number such as `0.041`. The asset intentionally does not call cloud pricing APIs in the worker preflight path.

### `finops:budget_remaining`

```bash
queue_class_shared_asset finops budget_remaining "gdpr-processing" min_remaining=25
```

Reads `/var/tmp/queuebash_budget_gdpr-processing.txt`. The file may contain either a plain number or `remaining=NUMBER`.

### `gcp:auth_active`

```bash
queue_class_shared_asset gcp auth_active _
```

Checks that `gcloud auth print-access-token` succeeds. It does not print the token.

### `azure:auth_active`

```bash
queue_class_shared_asset azure auth_active _
```

Checks that `az account get-access-token --resource https://management.azure.com/` succeeds. It does not print the token.

## Classes

Bundled examples:

- `CLOUD_COMPUTE_GDPR`
- `CLOUD_COMPUTE_ITAR`
- `CLOUD_GCP_GDPR`
- `CLOUD_AZURE_GDPR`
- `CLOUD_AZURE_UK_DPA`

## Prometheus reporter

`reporters.d/prom.sh` adds:

```bash
prom:textfile
```

Enable explicitly:

```bash
QUEUEBASH_REPORTERS="prom"
QUEUEBASH_PROM_DIR="/var/lib/prometheus/node-exporter"
QUEUEBASH_PROM_EVENTS="failed,pol_blocked,runtime_cap_violation,log_overflow_kill"
```

This is a reporting plugin, not an asset. It observes logged events and writes a textfile for node-exporter style scraping.

## net_usage remains absent

Do not add `assets.d/net_usage.sh`. The canonical charged-link asset is `net:allowance` in `assets.d/net.sh`; `net_usage` is compatibility naming only.
