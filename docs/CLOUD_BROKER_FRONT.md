# queue cloud broker front

`queue cloud` is a unified operator-facing broker front over the existing
cloud brokerage layers:

- `cloud_resource`: inventory, claim, lease, heartbeat, release, reconcile,
  and explain over file-backed resource records.
- `cloud_provision`: templates, plan, validate, explain, dry-run, approval,
  live-gate contract, and registry handoff.
- `cloud_infra`: named service lifecycle helper rails for plan/start/stop/status.
- `cloud_signals`: local policy evidence for cost and service availability.

This package does **not** add new cloud provider logic. It wraps the provider
helpers that already exist and gives users one stable command surface.

## Commands

```sh
queue cloud providers --json
queue cloud services --json
queue cloud signals platforms --json
queue cloud resource list --json
queue cloud provision templates --json
queue cloud provision plan aws-ec2-gdpr --json
queue cloud infra list --json
queue cloud infra plan aws-gdpr-compute start --json
queue cloud broker explain --capability vm --profile gdpr-compute --provider aws --region eu-west-2 --service compute --estimated-hourly-usd 0.50 --json
```

## Boundaries

`queue cloud` is not a scheduler rewrite and not a live provisioner.

It must not:

- perform live cloud API discovery;
- create, start, stop, or destroy resources except through existing explicit
  `cloud_infra` helper gates;
- bypass provisioning approval/live-gate contracts;
- bind resource claims to job lifecycle;
- refactor queue dispatch; or
- treat local cost catalog examples as live provider pricing.

Future work may add `queue submit --uses-cloud ...` once the front is stable,
but this package deliberately stops at the broker-facing command surface.

## Regulatory and corporate policy references

Brokerage decisions may need to point reviewers at the policies that justify or
block a placement. The broker therefore propagates local policy references from
`cloud_signals` availability and cost catalogs into `queue cloud broker explain`
JSON output.

Example top-level fields:

```json
{
  "policy_reference_mode": "local_policy_links_only",
  "policy_references": [
    {
      "id": "gdpr-cross-border-screening",
      "type": "regulatory",
      "title": "GDPR / UK data protection screening",
      "uri": "policy://regulatory/gdpr-uk-dpa-screening"
    },
    {
      "id": "corp-finops-standard",
      "type": "corporate",
      "title": "Corporate FinOps budget guardrail",
      "uri": "policy://corporate/finops/cloud-budget-guardrails"
    }
  ]
}
```

`policy://...` URIs are placeholders for local corporate policy/document registry
links. Production deployments should replace them with organisation-approved
policy URLs, document IDs, GRC references, or intranet links.

This is **not** legal advice and does **not** prove compliance. It is an evidence
linkage mechanism so a reviewer can see which regulatory/corporate policies were
considered when the broker produced its local decision evidence.
