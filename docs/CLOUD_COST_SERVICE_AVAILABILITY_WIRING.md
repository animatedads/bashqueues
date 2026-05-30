# Cloud cost and service availability wiring

`providers.d/cloud_signals/cloud_signals_provider.sh` is the provider-neutral wiring point for local cost and service availability evidence across the major cloud platforms currently tracked by bashqueues:

- OCI
- AWS
- Azure
- GCP
- IBM Cloud

This is a fixture-first/local-policy layer. It does **not** call live cloud APIs, does **not** query billing, does **not** read provider credentials, and does **not** mutate cloud resources or queue dispatch.

## Purpose

The cloud provisioning and cloud resource layers need a stable way to consume cost and service-availability facts without learning every provider API shape. This provider emits normalized JSON decisions from local policy/catalog files so later packages can wire those facts into provisioning gates and resource claims.

## Commands

```bash
providers.d/cloud_signals/cloud_signals_provider.sh platforms --json
providers.d/cloud_signals/cloud_signals_provider.sh availability-check --provider aws --region eu-west-2 --service compute --json
providers.d/cloud_signals/cloud_signals_provider.sh cost-check --provider aws --region eu-west-2 --service compute --estimated-hourly-usd 0.50 --monthly-budget-usd 750 --json
providers.d/cloud_signals/cloud_signals_provider.sh explain --provider aws --region eu-west-2 --service compute --estimated-hourly-usd 0.50 --monthly-budget-usd 750 --json
```

If installed through `queuebash.sh`, the same helper is available as:

```bash
queue cloud-signals platforms --json
queue cloud-signals explain --provider oci --region uk-london-1 --service compute --estimated-hourly-usd 0.50 --json
```

## Schemas

The command emits these contract schemas:

- `queuebash.cloud_signals.platforms.v1`
- `queuebash.cloud_signals.availability.v1`
- `queuebash.cloud_signals.cost.v1`
- `queuebash.cloud_signals.explain.v1`

## Policy files

Default local policy files are:

```text
policies.d/cloud-signals/service-availability.example.json
policies.d/cloud-signals/cost-catalog.example.json
```

Override them with:

```bash
QUEUEBASH_CLOUD_SIGNALS_POLICY=/path/service-availability.json
QUEUEBASH_CLOUD_SIGNALS_COST_CATALOG=/path/cost-catalog.json
```

or with command-line flags:

```bash
--policy FILE
--cost-catalog FILE
```

## Decision rules

Availability decisions:

- `available` -> `allow`
- `limited` -> `review`
- `unavailable` or `disabled` -> `deny`
- unknown region/service -> `review`

Cost decisions:

- estimated hourly cost over local ceiling -> `deny`
- estimated monthly cost over local budget -> `deny`
- missing cost policy -> `review`
- within local policy -> `allow`

## Boundaries

This layer is advisory evidence for governance gates. It is not a scheduler, not a cloud API client, not a billing scraper, and not a provisioning implementation. Future cloud provisioning work may consume these decisions, but ordinary queue dispatch must not call provider APIs or create resources.
