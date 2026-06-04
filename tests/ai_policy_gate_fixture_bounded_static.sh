#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail(){ echo "[FAIL] $*" >&2; exit 1; }

bash -n tests/ai_policy_gate_fixture_smoke.sh || fail 'bounded smoke shell syntax failed'
bash -n tests/ai_policy_gate_fixture_core_smoke.sh || fail 'core stage shell syntax failed'
bash -n tests/ai_policy_gate_fixture_legal_hint_smoke.sh || fail 'legal hint stage shell syntax failed'
python3 -m py_compile tests/ai_policy_gate_fixture_examination_matrix.py || fail 'examination matrix py_compile failed'

grep -q 'queuebash.ai_policy_gate.fixture_smoke_summary.v1' tests/ai_policy_gate_fixture_smoke.sh || fail 'final summary schema missing'
grep -q 'queuebash.ai_policy_gate.fixture_stage_result.v1' tests/ai_policy_gate_fixture_smoke.sh || fail 'stage result schema missing'
grep -q 'start_new_session=True' tests/ai_policy_gate_fixture_smoke.sh || fail 'process-group isolation missing'
grep -q 'os.killpg' tests/ai_policy_gate_fixture_smoke.sh || fail 'process-group kill missing'
grep -q 'QUEUEBASH_AI_POLICY_GATE_STAGE_TIMEOUT' tests/ai_policy_gate_fixture_smoke.sh || fail 'stage timeout knob missing'
grep -q 'ai_policy_gate_fixture_core_smoke.sh' tests/ai_policy_gate_fixture_smoke.sh || fail 'core stage not wired'
grep -q 'ai_policy_gate_fixture_examination_matrix.py' tests/ai_policy_gate_fixture_smoke.sh || fail 'matrix stage not wired'
grep -q 'ai_policy_gate_fixture_legal_hint_smoke.sh' tests/ai_policy_gate_fixture_smoke.sh || fail 'legal hint stage not wired'

echo '[PASS] ai policy gate fixture bounded static contract'
