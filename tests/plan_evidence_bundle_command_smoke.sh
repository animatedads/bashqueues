#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
export QUEUEBASH_BUNDLED_INSTALL_MODE=never
trap 'rm -rf "$QUEUEBASH_ROOT"' EXIT
source ./queuebash.sh >/dev/null
out="$(queue plan evidence fixtures/plan/runtime/aws-step-functions.json --json)"
python3 - "$out" <<'PY'
import json, sys
obj=json.loads(sys.argv[1])
assert obj['schema']=='queue.plan.evidence.v1'
assert obj['evidence']['counts']['runtime_job_status'] >= 1
assert obj['review']['safe_to_apply'] is False
print('PASS plan_evidence_bundle_command_smoke')
PY
