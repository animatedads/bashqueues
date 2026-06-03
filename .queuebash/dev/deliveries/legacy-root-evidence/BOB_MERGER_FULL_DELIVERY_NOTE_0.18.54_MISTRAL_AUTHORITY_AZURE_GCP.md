# 0.18.54 BOB_MERGER Mistral, scratchpad authority guard, and Azure/GCP parity merge

Base:

- `bashqueues_0.18.53_BOB_MERGER_qbtest_embedded_function_tests_full_delivery.zip`

Applied patchsets:

- `bashqueues_0.18.52_BOB11_ask_mistral_live_provider_pack_patchset.zip`
- `bashqueues_0.18.52_BOB2_scratchpad_authority_shape_guard_patchset.zip`
- `bashqueues_0.18.52_BOB10_azure_gcp_first_tier_platform_parity.patchset.zip`

Merger classification:

- README/CHANGELOG ledger hits: expected.
- Version-number hits: expected; final runtime version advanced to `0.18.54` because Mistral adds real ask-provider command surface on top of the accepted `0.18.53` QBTEST master.
- Scratchpad hit: expected; merged by item id and preserved Bob2 authority-shape repairs.
- `queuebash.sh` runtime overlap: inspected. Bob11 adds Mistral provider branches in the `queue ask` provider region. Bob10's `queuebash.sh` patch only carried version identity from its source line. No queue-dev/QBTEST changes were overwritten.

Preserved from prior accepted master:

- 0.18.53 QBTEST embedded function tests.
- 0.18.52 dev context / think / handover.
- 0.18.51 version-guard cleanup.
- bounded `queue dev patchset inspect --target` behaviour.
- OpenAI-compatible, watsonx, OpenAI, Anthropic, Gemini/Ollama/fixture ask-provider behaviour.
- cloud resource reconcile work.
- provider-family consistency work.

Boundary notes:

- Mistral live use remains gated by `QUEUEBASH_AI_LIVE_ENABLED` and default tests are fixture-only.
- Azure/GCP first-tier platform parity is docs/policy/static-contract work only: no live cloud API calls, no credentials required by default, no provisioning/destruction, and no dispatch refactor.
- Scratchpad authority records now satisfy the object-shape guard (`type`, `name`, `confidence`).
