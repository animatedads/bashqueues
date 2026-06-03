# Cloud platform parity

Current verdict: **platform coverage is not equal yet**.

OCI, IBM, AWS, and GCP now have useful provider/governance contract coverage, but the platforms are still not equal overall. AWS is first-tier for contract coverage after Bob10's uplift. GCP has an accepted Bob2 fixture-first provider contract pack, but it is not first-class yet because cost/ITAR/resource parity and primary-source validation remain incomplete. Azure now has an initial Bob2 contract backfill, but remains thinner than AWS and not first-class until cost/ITAR/resource parity and primary-source validation are complete.

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
| GCP | yes | yes | yes | partial | partial | Accepted Bob2 provider-contract pack with fixtures/tests; still needs first-tier cost/ITAR/resource parity and primary-source validation. |
| OCI | partial | yes | partial | no | no | Strong provider contract, docs, fixtures and tests; needs normal asset family and cost/ITAR parity. |
| IBM | partial | yes | yes | no | yes | Strong identity/governance/FinOps posture; needs provider-resource parity and ITAR. |
| Azure | yes | partial | partial | partial | partial | Initial Bob2 provider-contract backfill, fixtures and tests added; still needs first-tier cost/ITAR/resource parity and primary-source validation. |

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
