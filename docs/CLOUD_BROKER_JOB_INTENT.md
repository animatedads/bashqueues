# Cloud broker job intent explain

`queue cloud broker job-intent` connects the existing advisory cloud intent
recorded by `queue submit --uses-cloud` to the cloud broker explainer.

It is intentionally non-mutating. It reads job metadata and produces broker
evidence; it does not claim `cloud_resource` capacity, create a
`cloud_provision` plan, call `cloud_infra`, contact a cloud API, or alter
queue dispatch behaviour.

## Commands

```sh
queue cloud broker job-intent JOB --json
queue cloud broker job-intent --job-file FILE --json
providers.d/cloud_broker/cloud_broker_provider.sh job-intent --job-file FILE --json
```

## Output schema

The machine-readable response uses:

```text
queuebash.cloud_broker.job_intent.v1
```

For jobs without `USES_CLOUD=1`, the response is `decision=not_applicable`.
For jobs with cloud intent, the response embeds the current
`queuebash.cloud_broker.explain.v1` broker evidence under `broker_explain` and
includes explicit boundary flags:

```json
{
  "non_mutating": true,
  "live_api_calls": false,
  "dispatch_binding": false,
  "cloud_resource_claim": false,
  "cloud_provision_call": false,
  "cloud_infra_call": false
}
```

## Boundary

This feature is a read-only advisory bridge between submitted job intent and
broker evidence. Future work may bind cloud claims to job lifecycle, but this
patch deliberately does not do that.
