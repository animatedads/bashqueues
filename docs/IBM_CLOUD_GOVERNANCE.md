# IBM Cloud identity and sovereignty governance

Version: 0.18.11

0.18.11 adds a narrow IBM Cloud governance rail. It is intentionally a contract and class-template release, not a full IBM integration suite.

## Scope

Included:

- `assets.d/ibm_identity.sh`
- `CLOUD_IBM_GDPR`
- `CLOUD_IBM_FINREG`
- `CLOUD_IBM_LEGAL_READONLY`
- `CLOUD_IBM_LEGAL_COMPLIANCE`
- IBM region/jurisdiction mapping examples
- static and fake-CLI smoke tests

Not included yet:

- IBM FinOps scraper
- IBM Activity Tracker / Cloud Logs reporter
- IBM Monitoring reporter
- IBM HPCS key provider
- IBM Watson advisory provider
- IBM Satellite worker identity

## Asset family

The executable bashqueues asset family is:

```text
ibm_identity
```

Facilities:

```text
ibm_identity:auth_active
ibm_identity:target_region_allowed
```

The logical contract is the IBM identity rail described in the roadmap as `ibm:auth_active` and `ibm:target_region_allowed`. The family name is `ibm_identity` so the class asset record matches the delivered plugin filename `assets.d/ibm_identity.sh`.

## Environment knobs

```bash
QUEUEBASH_IBM_REGION=eu-gb
QUEUEBASH_IBM_ACCOUNT_ID=
QUEUEBASH_IBM_RESOURCE_GROUP=
QUEUEBASH_IBM_AUTH_REQUIRED=1
```

`QUEUEBASH_IBM_REGION` is preferred. If it is absent, the asset falls back to `QUEUEBASH_CLOUD_REGION`.

## Identity gate

```bash
queue_class_shared_asset ibm_identity auth_active _
```

This checks that the `ibmcloud` CLI exists and that `ibmcloud target` returns an active target/session. It does not print tokens or secrets.

To require a specific account ID:

```bash
queue_class_shared_asset ibm_identity auth_active ACCOUNT_ID
```

The asset compares the expected account against `QUEUEBASH_IBM_ACCOUNT_ID` first, then against account information visible in `ibmcloud target` output.

## Region gate

```bash
queue_class_shared_asset ibm_identity target_region_allowed GDPR
```

Supported framework targets:

```text
GDPR
UK_DPA
FINREG
LEGAL
IBM_ALL
```

Default region groups:

```text
GDPR:   eu-de,eu-gb,eu-es
UK_DPA: eu-gb
FINREG: us-south,us-east,ca-tor,eu-de,eu-gb,eu-es,au-syd,jp-tok,jp-osa,br-sao
LEGAL:  us-south,us-east,br-sao,ca-tor,eu-de,eu-gb,eu-es,au-syd,jp-osa,jp-tok
```

These mappings are governance templates. They do not assert that an individual workload is compliant with IBM Cloud for Financial Services, GDPR, UK DPA, legal hold, or any other regulatory regime. They are preflight gates that require operators to select an allowed IBM region before the job can run.

## Class templates

### CLOUD_IBM_GDPR

Strict IBM Cloud GDPR workload class. Requires IBM identity and an IBM GDPR region.

### CLOUD_IBM_FINREG

Serialized regulated financial-services posture template. It combines IBM identity/region checks with legal and integrity gates.

### CLOUD_IBM_LEGAL_READONLY

Legal read-only rail for evidence/reporting operations that should not perform destructive actions.

### CLOUD_IBM_LEGAL_COMPLIANCE

Legal/compliance rail for governed operations that require IBM identity, legal retention/jurisdiction checks, and integrity evidence.

## Canonical paths

Use current bashqueues paths:

```text
~/.queuebash/...
/etc/queuebash/...
/var/lib/queuebash/...
```

Do not use legacy `legacy system policy namespace` namespace in new IBM policy examples.

## 0.18.12 IBM FinOps, legal, and integrity contract

0.18.12 adds the IBM FinOps/legal/integrity layer without introducing live IBM
API calls in the worker preflight path. The contract is intentionally local and
cache-backed:

- `assets.d/ibm_finops.sh` reads a local IBM FinOps cache and health file.
- `ibm_finops:cost_cache_fresh` requires the local cache to be recent.
- `ibm_finops:budget_remaining` checks a named budget remaining value.
- `ibm_finops:spend_below` checks cached spend for a scope/period.
- `ibm_finops:anomaly_free` blocks on cached FinOps anomaly severity.

The default example paths are canonical queuebash paths:

```text
/etc/queuebash/finops/ibm_cost_cache.json
/etc/queuebash/finops/ibm_finops.health
/etc/queuebash/legal_registry.tsv
/etc/queuebash/manifests/ibm_finreg.manifest
```

The cache schema is documented in `policies.d/finops/ibm.env.example`, with
sample files in `examples/ibm/`. A future collector may populate these files
from IBM billing/cost APIs, but 0.18.12 only defines the gate contract and local
cache semantics.

`CLOUD_IBM_FINREG` and `CLOUD_IBM_LEGAL_COMPLIANCE` now include IBM FinOps cache
health gates alongside the IBM identity, sovereignty, legal, and integrity gates.
This is a template posture: sites should copy the class and replace dataset IDs,
registry paths, manifests, budgets, and spend thresholds with local policy.

Still out of scope for this release:

- IBM Cloud Logs / Activity Tracker reporter integration
- IBM HPCS key-provider contract
- IBM Watson advisory provider
- IBM Satellite worker identity
- live IBM FinOps scraper/collector
