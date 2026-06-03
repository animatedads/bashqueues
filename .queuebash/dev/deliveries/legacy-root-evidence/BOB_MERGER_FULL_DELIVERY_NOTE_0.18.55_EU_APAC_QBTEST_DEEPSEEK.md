# 0.18.55 BOB_MERGER EU/APAC cloud helpers, QBTEST polish, and DeepSeek merge

Merged onto accepted current base `bashqueues_0.18.54_BOB_MERGER_mistral_authority_azure_gcp_full_delivery.zip`.

Applied patch script route first:

- `bashqueues_0.18.55_BOB10_eu_apac_cloud_infra_helper_parity.patchset.zip` applied cleanly with its patch apply script.
- `bashqueues_0.18.55_BOB12_qbtest_usability_polish_patchset.zip` applied cleanly with its patch apply script using changed-function preconditions despite expected file-level ledger/scratchpad overlap.
- `bashqueues_0.18.55_BOB11_ask_deepseek_live_provider_pack_patchset.zip` reported the expected `queuebash.sh` precondition/version overlap after Bob10/Bob12. DeepSeek additions were reconciled manually from the patch diffs/files; the touched areas are independent of Bob10 cloud helpers and Bob12 QBTEST command polish.

Merger classification:

- README/CHANGELOG/version/scratchpad hits: expected.
- `queuebash.sh`: inspected; independent areas merged.
  - Bob10: version/cloud helper support files and cloud-infra registry/docs/tests.
  - Bob12: `_queue_dev_test_qbtest_command` usability polish.
  - Bob11: ask-provider discovery/help/live helper dispatch for `deepseek`.
- No queue dispatch refactor, no provisioning/destruction enablement, no live cloud API enablement.

Validation is recorded in `validation_0.18.55_BOB_MERGER_eu_apac_qbtest_deepseek_full_delivery.log` and cleanup in `cleanup_0.18.55_BOB_MERGER_eu_apac_qbtest_deepseek_full_delivery.log`.
