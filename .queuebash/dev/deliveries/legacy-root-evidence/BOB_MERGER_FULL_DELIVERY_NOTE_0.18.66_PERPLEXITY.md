# Bob Merger full delivery note: 0.18.66 Perplexity provider merge

Base: `bashqueues_0.18.65_BOB_MERGER_qbtest_wave3_wave8_function_coverage_full_delivery.zip`

Merged payload: `bashqueues_0.18.60_BOB11_ask_perplexity_live_provider_pack_patchset(1).zip`

Decision: the incoming 0.18.60 number is treated as Bob11 branch identity only. The provider lands under the current merger-line identity, `QUEUEBASH_VERSION="0.18.66"`.

Preserved:

- 0.18.65 embedded QBTEST wave3-wave8 coverage.
- Remote-admin transaction plan/apply/rollback work.
- Fake/malformed QBTEST placeholder absence.
- Source-first / toolchain-first merger discipline.

Added:

- `queue ask --provider perplexity` command integration.
- `bin/queue-ai-ask-perplexity`.
- `providers.d/ask/perplexity.sh`.
- Perplexity docs, policy examples, provider registry row, and fixture-only tests.

Boundary:

- No live call by default.
- No API key required for fixture/smoke tests.
- No shell execution of model output.
- No dispatch/provisioning/cloud-resource behaviour change.
