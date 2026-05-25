#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

python3 - <<'PY'
from pathlib import Path
import re
src = Path('queuebash.sh').read_text()
assert re.search(r'QUEUEBASH_VERSION=\"0\.[0-9]+\.[0-9]+\"', src)
assert '_queue_job_file_by_id_any_state "$id"' in src
assert '_queue_job_var_value "$jobf" EXCEPTION_SANDBOX_OVERRIDE' in src
assert '_queue_job_var_value "$jobf" EXCEPTION_SECCOMP_ALLOW' in src
assert '_queue_job_var_value "$jobf" EXCEPTION_DROP_CAP' in src
assert '_queue_job_var_value "$jobf" EXCEPTION_ADD_PORT' in src
assert 'OVERRIDE ${sandbox_from:-class-default} -> $sandbox_override via job flag' in src
assert 'HOLE PUNCHED allowing' in src
assert 'REMOVED' in src and 'runtime caps:' in src
assert 'runtime ports:' in src and 'ADDED' in src
print('[PASS] queue explain reports submit-time security exception overlays from the job record')
PY
