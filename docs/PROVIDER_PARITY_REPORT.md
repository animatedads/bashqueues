# Provider parity report

`providers.d/cloud_resource/provider_parity_report.py` is an offline governance
report for provider-family coverage. It turns the provider-family consistency,
platform parity, primary-source validation and fixture-first conventions into a
single human/JSON inspection surface.

The report is deliberately non-mutating:

- no live cloud API calls
- no credentials
- no provisioning or destruction
- no queue dispatch refactor
- no compliance promotion

## Usage

```bash
providers.d/cloud_resource/provider_parity_report.py --root .
providers.d/cloud_resource/provider_parity_report.py --root . --json
providers.d/cloud_resource/provider_parity_report.py --root . --family aws --json
providers.d/cloud_resource/provider_parity_report.py --root . --json --fail-on-missing
```

## JSON contract

The JSON output schema is:

```json
{
  "schema": "queuebash.provider_parity_report.v1",
  "provider": "provider_parity_report",
  "live_api_calls": false,
  "credentials_required": false,
  "cloud_mutation": false,
  "queue_dispatch_refactor": false,
  "summary": {
    "families_total": 10,
    "families_complete": 10,
    "families_incomplete": 0,
    "verdict": "complete"
  },
  "families": []
}
```

Each family reports required artifact buckets:

- docs
- provider_dirs
- policies
- fixtures
- tests

A complete report means required contract artifacts are present. It does not mean
the provider is live-enabled, compliant, certified, or first-tier unless the
platform parity and validation policies separately say so.

## Policy

The default policy is:

```text
policies.d/cloud-resource/provider-parity-report.json
```

It uses schema:

```text
queuebash.provider_parity_report_policy.v1
```

The policy can be replaced for a release review or a narrower provider family
review.
