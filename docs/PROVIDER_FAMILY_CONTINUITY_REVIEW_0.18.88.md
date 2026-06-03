# Bob14 provider-family continuity review — 0.18.88

Bob14 inherits Bob2's provider-family coverage lane. This review is scoped to
provider-family continuity, platform parity clarity, fixture-first provider
contracts, and docs/static tests. It deliberately avoids Bob10 provisioning and
resource lifecycle work, Bob11 ask-provider runtime work, and Bob13 queue-dev or
command/display-resource work.

## Review boundary

This review is docs/static-test work unless a concrete provider-family metadata
defect is found. It does not add live API calls, credentials, provisioning,
destruction, queue dispatch changes, scheduling changes, or provider output used
as shell.

## Current status summary

| Family | Review status | Continuity finding |
| --- | --- | --- |
| AWS | `first_tier_contract` | Contract coverage remains first-tier engineering coverage; no live mutation by default. |
| Azure | `first_tier_contract` | First-tier engineering status is reflected in policy/docs/tests; compliance still requires primary-source acceptance. |
| GCP | `first_tier_contract` | First-tier engineering status is reflected in policy/docs/tests; compliance still requires primary-source acceptance. |
| OCI | `high_standard_reference` | Docs, provider helper, policies, fixtures, classes, static tests, smoke tests, JSON tests, and explainability tests exist; remains non-live reference material. |
| IBM | `high_standard_reference` | Concrete metadata defect found: the consistency policy still had IBM `provider_dir`, `policy_dir`, and `fixture_dir` as null even though IBM helper/policy/fixture/test material exists. This review updates those fields while keeping IBM as `high_standard_reference`, not first-tier parity. |
| EU sovereign | `fixture_first_provider_family` | Fixture-first family remains mapped/pending validation. |
| APAC/China | `fixture_first_provider_family` | Fixture-first family remains mapped/pending validation. |
| GPU cloud | `fixture_first_provider_family` | Fixture-first family remains mapped/pending validation; GPU quota/export/data posture remains validation work. |
| Edge cloud | `fixture_first_provider_family` | Fixture-first family remains mapped/pending validation; locality/cache/log posture remains validation work. |
| Hybrid/on-prem | `fixture_first_provider_family` | Fixture-first family remains mapped/pending validation; site identity/legal posture remains validation work. |

## Defect fixed

`policies.d/cloud-resource/provider-family-consistency.json` described IBM as a
high-standard reference but left the structural location fields null. The actual
base contains:

- `providers.d/ibm/ibm_provider.sh`
- `policies.d/ibm/`
- `tests/fixtures/ibm/`
- `docs/IBM_PROVIDER_CONTRACTS.md`
- `docs/IBM_CLASS_CRITERIA.md`
- `docs/IBM_EXPLAINABILITY.md`
- `docs/IBM_LEGAL_COMPLIANCE.md`
- `tests/ibm_provider_contracts_static.sh`
- `tests/ibm_provider_fixture_smoke.sh`
- `tests/ibm_provider_json_contract_static.py`
- `tests/ibm_explain_static.sh`

The continuity policy now records these actual locations. The status remains
`high_standard_reference` to avoid implying first-tier parity or live support.

## Guardrail confirmations

- Provider helpers return normalized JSON facts, decisions, and evidence only.
- Provider-family presence is not first-tier parity.
- Fixture-first coverage is not legal/compliance acceptance.
- Default tests must not require credentials, network access, provisioning, or cloud mutation.
- Provider outputs must not be treated as shell commands.
- `queuebash.sh` is not changed by this review.

## README / cross-link finding

The top-level README is release-led and does not currently provide a compact
provider-family index. This patch adds a small provider-family cross-link block
near the top of the README so future reviewers can find the continuity/parity
material without searching historical release entries.

## Service-coverage handoff

The next Bob14 provider-family work should stage contract candidates for model
registry and container registry first, then vector database, data lake, GPU
marketplace, and distributed-framework discovery. These must remain advisory
provider facts/contracts and must not become queue scheduling or provisioning
rewrites.
