# 0.18.67 BOB_MERGER provider parity report merge

Merged Bob2 provider parity report branch payload onto the accepted 0.18.66 Perplexity/QBTEST coverage base.

Added offline provider-family parity reporting:

- `providers.d/cloud_resource/provider_parity_report.py`
- `policies.d/cloud-resource/provider-parity-report.json`
- `docs/PROVIDER_PARITY_REPORT.md`
- `tests/provider_parity_report_static.sh`
- `tests/provider_parity_report_smoke.sh`
- `tests/provider_parity_report_json_contract_static.py`

Boundaries preserved: no live cloud API calls, no credentials, no provisioning/destruction, no generic editor, and no queue dispatch refactor.

Validation and cleanup logs are included in this delivery.
