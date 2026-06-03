# 0.18.58 BOB_MERGER remote-admin ACL-gated policy commands full delivery

Merged onto the 0.18.56 Groq/status enum full delivery line with the 0.18.57 streams carried forward.

Included lanes:

- BOB2 scratchpad required-fields guard
- BOB11 Cerebras ask-provider pack
- BOB10 GPU cloud provisioning template parity
- BOB12 queue dev validate/scope gates
- BOB10 remote-admin ACL-gated policy commands contract

Merger route:

- sourced `queuebash.sh` first
- used `queue dev patchset inspect --patchset PATCH --json` first where available
- used patch apply scripts first where preconditions allowed
- treated README/CHANGELOG/version/scratchpad hits as expected ledger noise
- manually reconciled only independent queuebash command-surface overlaps
- used `bin/queue-dev-timeout` for bounded validation

Runtime command surfaces now include:

- `queue ask --provider cerebras`
- `queue dev validate`
- `queue dev scope-check`
- `queue remote-admin --actor ACTOR validate|config|client|acl|secret|audit ...`

Important preservation:

- fake malformed QBTEST placeholder remains absent
- real `_queue_now` embedded QBTEST remains present
- documentation examples use `EXAMPLE_QBTEST:*` markers
- `assets.d/net_usage.sh` remains absent

Validation and cleanup logs are included in this delivery.
