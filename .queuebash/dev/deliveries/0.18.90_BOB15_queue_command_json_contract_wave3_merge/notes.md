# 0.18.90 BOB15 queue command JSON contract wave3 merge

Base: bashqueues_0.18.89_BOB15_service_coverage_model_container_registry_full_delivery.zip
Input: bashqueues_0.18.89_BOB13_queue_command_json_contract_wave3.patchset.zip

Merge notes:
- queue dev merge-plan was used; it reported unsupported_manifest_shape because this older patchset uses manifest items[] rather than entries[].
- Manual reconciliation applied the real manifest items after verifying queuebash.sh baseline drift from Bob15 was version-only.
- README/CHANGELOG were normalized to 0.18.90 Bob15 and not wholesale overwritten.
- scratchpad was merged by item ID only.
- root validation/cleanup/merge_manifest files from the patchset were moved into this delivery record rather than left at repository root.

Functional scope:
- queue show JOB --json
- queue history JOB --json
- queue tail JOB --json --no-follow
- queue tail JOB --json in follow mode returns queuebash.error.v1
