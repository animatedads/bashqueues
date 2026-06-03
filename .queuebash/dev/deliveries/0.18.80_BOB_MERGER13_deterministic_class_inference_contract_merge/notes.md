# 0.18.80 BOB_MERGER13 deterministic class inference contract merge

Merged Bob2 deterministic class inference contract patchset onto 0.18.79 AI broker runtime base.

Preserved:
- AI broker runtime and broker contract material
- embedded API contract
- ask command/asset/usage inventory backfill
- grid energy cost model
- QBTEST add/extract/installer support

Added:
- offline queue class-infer helper
- deterministic command fingerprint/recommend/explain contracts
- class inference policy fixtures/docs/tests

Boundary:
- no submit-path enforcement
- no live API calls
- no provisioning
- no queue dispatch refactor beyond additive wrapper
- no automatic class mutation
