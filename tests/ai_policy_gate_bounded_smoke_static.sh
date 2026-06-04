#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
file="tests/ai_policy_gate_fixture_smoke_bounded.sh"
[[ -x "$file" ]] || { echo "missing executable bounded AI policy gate smoke: $file" >&2; exit 1; }
grep -q 'queuebash.ai_policy_gate.fixture_smoke_bounded.v1' "$file"
grep -q 'QUEUEBASH_AI_POLICY_GATE_STAGE_TIMEOUT' "$file"
grep -q -- '--stage NAME' "$file"
grep -q 'stage: .* rc=' "$file"
grep -q 'disabled-default' "$file"
grep -q 'decision-normalisation' "$file"
grep -q 'per-job-and-redaction' "$file"
grep -q 'jobid-and-endpoint-safety' "$file"
grep -q 'timeouts' "$file"
# The bounded smoke must stay fixture/deterministic only. Live/external-provider
# dependency checks remain in the legacy full smoke so enterprise validation can
# tell feature regression apart from environment/network setup.
! grep -q 'QUEUEBASH_AI_POLICY_GATE_PROVIDER=gemini' "$file"
! grep -q 'QUEUEBASH_AI_POLICY_GATE_OLLAMA_URL' "$file"
echo "PASS ai_policy_gate_bounded_smoke_static"
