# 0.18.60 BOB_MERGER IBM/OCI cloud enablement provider contracts

Built from accepted 0.18.59 BOB_MERGER patchset apply backup hardening full delivery.

Applied additive patchset: `cloud_enablement_ibm_oci.zip`.

Added IBM provider contract surface:

- `providers.d/ibm/ibm_provider.sh`
- `docs/IBM_PROVIDER_CONTRACTS.md`
- `docs/IBM_CLASS_CRITERIA.md`
- `docs/IBM_EXPLAINABILITY.md`
- `docs/IBM_LEGAL_COMPLIANCE.md`
- `policies.d/ibm/*`
- `tests/fixtures/ibm/*`
- `tests/ibm_*` provider tests

Added OCI asset helper:

- `assets.d/oci.sh`

Boundary:

- no live IBM or OCI API calls
- no provider credentials required by default
- no provisioning/destruction
- no queue dispatch refactor
- IBM provider tests are fixture-first

Version identity was bumped to `QUEUEBASH_VERSION=0.18.60` because this adds provider/asset surface.
