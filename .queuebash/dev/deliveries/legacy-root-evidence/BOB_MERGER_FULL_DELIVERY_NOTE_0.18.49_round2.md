# Bob the Merger full delivery note - round 2

Base: `bashqueues_0.18.49_BOB_MERGER_full_delivery.zip`

Applied inventory, in order:

1. `bashqueues_0.18.49_BOB12_patchset_file_registry_hardening.patchset.zip`
2. `bashqueues_0.18.50_BOB2_followup_static_version_pin_cleanup_patchset.zip`
3. `bashqueues_0.18.49_BOB11_ask_watsonx_live_provider_pack_patchset.zip`

Runtime version remains `QUEUEBASH_VERSION="0.18.49"`. The Bob2 0.18.50 patchset is a follow-up static-test/version-pin cleanup and does not carry a runtime version bump.

## Queue dev examination

Bob12 materially extends the controlled internal dev API:

- `queue dev files scan` now emits `scan_records` and `missing_baseline_md5`.
- `queue dev patchset create` now includes manifest summaries, change types, and explicit preconditions.
- `queue dev patchset inspect --patchset ZIP [--target DIR] [--json]` is now present.

Bob11 changes a separate command lane: `queue ask --provider watsonx`. The `queue dev` dispatcher, file-registry command, and patchset command were preserved while adding Bob12's inspect path.

## Cross-stream resolution

- `queuebash.sh`: 3-way merged. Bob12's `queue dev` changes and Bob11's watsonx changes are in separate areas and both are present.
- `README.md` / `CHANGELOG.md`: additive ledger merge. Bob10, Bob12, and Bob11 release entries are preserved.
- Static tests: resolved overlapping version-pin cleanup by keeping Bob12/Bob11 assertions while preserving Bob2's `0.18.49+` compatibility where applicable.
- `.queuebash/dev/scratchpad.json`: merged by item ID. One Bob2 follow-up scratchpad item was added; final scratchpad count is 177.

## Validation

Passed:

- `bash -n queuebash.sh`
- focused shell syntax checks for touched shell tests/providers
- Python compile checks for Python tests and `bin/queue-ai-ask-watsonx`
- Bob12 queue-dev hardening static and smoke tests
- Bob2 follow-up static version-pin tests
- Bob11 OpenAI/Anthropic preservation tests and watsonx static/smoke tests
- selected JSON/static contract tests
- `queue dev patchset inspect` probes against Bob12 and Bob11 patchsets
- cleanup checks: no merge conflict artifacts, no editor backup artifacts, `assets.d/net_usage.sh` absent, `caps.d/net_usage.sh` present
