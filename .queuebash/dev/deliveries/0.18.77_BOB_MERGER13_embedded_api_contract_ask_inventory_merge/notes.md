# 0.18.77 BOB_MERGER13 embedded API contract and ask inventory merge

Base: 0.18.76 BOB_MERGER13 ask inventory command surface backfill.
Input: 0.18.76 BOB11 embedded API contract patchset.

Merged Bob11 contract/docs/policies/tests while preserving the existing 0.18.76 ask command-surface and asset-inventory fixes. queuebash.sh code change is version identity only because Bob11 runtime patchset only changed the version line; embedded API remains contract-first documentation/tests/examples.

No assets.d/net_usage.sh restored.
