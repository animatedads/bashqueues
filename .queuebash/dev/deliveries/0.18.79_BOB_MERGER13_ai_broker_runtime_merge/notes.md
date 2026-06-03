# 0.18.79 BOB_MERGER13 AI broker runtime merge

Merged Bob11 queue AI broker runtime patchset onto accepted 0.18.78 Merger-13 base.

Preserved:
- embedded API contract
- AI broker contract docs/policies/tests
- ask command/usage/asset inventory backfill
- grid_energy cost model grounding
- QBTEST add/extract/installer support

Included:
- `bin/queue-ai-broker`
- `queue ai providers|models|health|explain|chat|json` runtime dispatch
- broker runtime implementation documentation
- runtime static/smoke/JSON contract tests

Repair during merge:
- bounded `tests/queue_ai_broker_runtime_json_contract_static.py` subprocess calls with explicit timeout and stderr diagnostics, because the original check_output form was unreliable in the sandbox loop.
