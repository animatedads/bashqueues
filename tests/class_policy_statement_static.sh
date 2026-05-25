#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
from pathlib import Path
q = Path('queuebash.sh').read_text()
cron = Path('bin/bashqueues-cron-ticker.py').read_text()
pol = Path('policies.d/class-statement/default.env').read_text()
assert 'QUEUEBASH_VERSION="0.17.26"' in q
assert 'class-statement' in q
assert '_queue_submit_policy_check()' in q
assert '--reason)' in q
assert '--authorisation|--authorization)' in q
assert '_queue_authorisation_generate()' in q
assert 'AUTHORISATION_COMMAND_SHA256' in q
assert 'CLASS_POLICY_EXCEPTION_FLAGS_REQUIRE' in pol
assert 'CLASS_POLICY_CRON_MIN_SANDBOX_LEVEL' in pol
assert 'BASHQUEUES_AUTHORISATION' in cron
assert '_resolve_cron_class' in cron
assert 'below crontab minimum' in cron
print('[PASS] central class policy statement and authorisation hooks are present')
PY
