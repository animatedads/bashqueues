# Cloud platform parity

Current verdict: **platform coverage is not equal yet**.

OCI, IBM, AWS, Azure, and GCP now have useful provider/governance contract coverage, but the platforms are still not equal overall. AWS is first-tier for contract coverage after Bob10's earlier uplift. Azure and GCP are first-tier for contract coverage after the 0.18.52 Bob10 uplift. Azure and GCP first-tier status means engineering contract parity only: provider contracts, assets, classes, policy examples, fixtures, FinOps/cost posture, ITAR/export-control posture, explainability, and tests. It is not legal certification or permission for live provisioning.

Parity requires more than a class file. A platform is first-class only when it has the same minimum coverage set:

- identity/auth posture
- provider JSON contract
- asset checks
- policy examples
- class templates
- region/sovereignty model
- GDPR/data-protection posture
- ITAR/export-control posture
- legal retention/jurisdiction notes
- audit evidence model
- FinOps/cost posture
- fixtures
- static/smoke/JSON tests

## Current matrix

| Platform | Provider contract | Governance | Data protection | ITAR | FinOps | Status |
| --- | --- | --- | --- | --- | --- | --- |
| AWS | yes | yes | yes | yes | yes | First-tier contract coverage in this line; no live provisioning or dispatch rewrite. |
| GCP | yes | yes | yes | yes | yes | First-tier contract coverage in 0.18.52; fixture-first, non-mutating, and still pending legal primary-source validation. |
| OCI | partial | yes | partial | no | no | Strong provider contract, docs, fixtures and tests; needs normal asset family and cost/ITAR parity. |
| IBM | partial | yes | yes | no | yes | Strong identity/governance/FinOps posture; needs provider-resource parity and ITAR. |
| Azure | yes | yes | yes | yes | yes | First-tier contract coverage in 0.18.52; fixture-first, non-mutating, and still pending legal primary-source validation. |

## 0.18.32 AWS and GCP merge

AWS remains promoted from not-first-class to first-tier contract coverage. The uplift adds AWS provider contract helper, AWS asset checks, policy examples for governance/GDPR/data-protection/ITAR/FinOps, class templates, fixtures, and tests.

GCP is now rolled in from Bob2's accepted provider contract pack. It adds GCP provider docs, class criteria, explainability, legal/compliance posture, provider fixture helper, policy examples, class templates, fixtures, and static/smoke/JSON tests. The GCP pack is fixture-first and non-mutating: no live GCP API calls, no credentials required by default, no provisioning, and no queue dispatcher refactor.

Do not claim equal functionality until every platform meets the mandatory coverage set.


## 0.18.33 Azure backfill

Azure receives a fixture-first provider contract backfill with provider docs, class criteria, explainability, legal/compliance posture, provider helper, policies, class templates, fixtures, and static/smoke/JSON tests. It remains non-mutating and does not add live Azure API calls, credentials, provisioning, destruction, or queue dispatcher changes.

## 0.18.34 EU sovereign provider backfill

EU sovereign provider contracts now exist for OVHcloud, Scaleway, Hetzner Cloud, and Open Telekom Cloud. This is a fixture-first Bob2 provider pack with docs, policy examples, class templates, provider helper, fixtures, and static/smoke/JSON tests. It is not first-tier platform parity: provider-specific identity, cost, legal, sovereignty, operational, and primary-source validation remain incomplete.


## 0.18.35 APAC/China provider contracts

APAC/China provider contracts now exist, and GPU cloud provider contracts now exist for Alibaba Cloud, Tencent Cloud, and Huawei Cloud. They are fixture-first and non-mutating: no live provider API calls, no credentials required by default, no provisioning, and no queue dispatcher refactor. Do not claim compliance or first-tier parity until primary-source validation and full parity coverage are complete.

## 0.18.36 GPU cloud provider contracts

GPU cloud provider contracts now exist for CoreWeave, Lambda Cloud, and NVIDIA DGX Cloud. They are fixture-first and non-mutating; GPU capacity, quota, cost, export-control, and legal posture remain mapped pending validation.

## 0.18.37 edge cloud provider pack

Edge cloud provider contracts now exist for Cloudflare Workers, Fastly Compute@Edge, and Fly.io. They are fixture-first and non-mutating. They add provider docs, policy examples, class templates, fixtures, JSON contracts, explainability, and tests. Edge coverage remains mapped/pending validation and is not first-class parity.


## 0.18.41 Bob2 hybrid/on-prem provider-contract merge

Hybrid/on-prem provider coverage is now mapped as a fixture-first Bob2 provider family for VMware/vCloud, OpenStack, and OpenShift. This adds provider contracts, class criteria, explainability, legal/compliance posture, provider helper, policy examples, class templates, fixtures, and static/smoke/JSON tests. It is not first-tier parity and does not perform live vCenter/OpenStack/OpenShift API calls, require credentials, provision/deploy/destroy resources, or refactor queue dispatch.

## 0.18.43 Bob2 provider-family consistency backfill

Bob2 provider-family consistency backfill adds a machine-readable status file and
meta-tests for the provider-family packs already in the tree. It clarifies that
provider-family presence is not the same as first-tier parity or legal/compliance
acceptance.

Current status summary:

- AWS: first-tier contract coverage.
- OCI and IBM: high-standard reference provider/governance material.
- GCP, Azure, EU sovereign, APAC/China, GPU cloud, edge cloud, and hybrid/on-prem:
  accepted fixture-first provider-family packs, mapped pending validation.

The overall verdict remains `not_equal_yet` until every platform family reaches
validated parity across provider contracts, identity, region/sovereignty,
legal/compliance, audit/evidence, FinOps/cost where applicable, fixtures,
explainability, JSON contracts, and focused tests.

## 0.18.44 Bob2 provider explainability standardization

Provider-family parity now includes a shared explainability standard. Provider
families must document decision, reason, source, fail-closed posture,
remediation hint, and validation status. This is a consistency and honesty
backfill, not a live-provider or compliance-certification package.

## 0.18.52 Bob10 Azure/GCP first-tier contract uplift

Azure and GCP are promoted to first-tier **contract coverage**. This adds explicit FinOps/cost and ITAR/export-control policy examples, first-tier parity assertions, and a dedicated first-tier documentation/test layer. The uplift remains fixture-first and non-mutating: no live Azure/GCP API calls, no credentials required by default, no provisioning/destruction, and no queue dispatch refactor.

The overall verdict remains `not_equal_yet` because first-tier engineering-contract coverage is not the same as legal compliance certification or equal maturity across OCI, IBM, EU sovereign, APAC/China, GPU, edge, and hybrid/on-prem families.

## Primary-source validation status

Provider-family coverage is not enough to claim legal compliance or production parity. Region, sovereignty, export-control, ITAR, customer-data, and provider capability claims must remain mapped/pending validation until checked against primary sources and explicitly accepted. See `docs/PROVIDER_PRIMARY_SOURCE_VALIDATION.md`.
