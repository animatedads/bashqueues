#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
from pathlib import Path
q = Path('queuebash.sh').read_text()
p = Path('queuemgr_panel.py').read_text()
assert 'QUEUEBASH_VERSION="0.17.19"' in q
for needle in [
    'queue_class_global_exclusive_claim()',
    'queue_class_global_shared_claim()',
    'queue_class_global_exclusive_asset()',
    'queue_class_global_shared_asset()',
    '_queue_global_command()',
    'global_claim_acquired',
    'global_claim_blocked',
    'global_claim_released',
    'global:claim:',
]:
    assert needle in q, needle
assert 'ViewState("global", "Global Resources", load_global_resources, detail_global_resource)' in p
assert 'def execute_global_command' in p
assert '"global": "G"' in p
assert 'docs/GLOBAL_RESOURCES.md'
print('[PASS] global shared resource slots are wired into queuebash and QueueManager')
PY
