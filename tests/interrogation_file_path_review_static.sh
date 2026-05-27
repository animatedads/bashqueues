#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }
grep -q 'QUEUEBASH_VERSION="0.18.6"' queuebash.sh || fail 'version not bumped to 0.18.6'
grep -q 'FILEPROFILE_OBSERVED_DELETE_PATHS' bin/queue-interrogate-compile || fail 'delete path field missing'
grep -q 'FILEPROFILE_OBSERVED_WRITE_PATHS' bin/queue-interrogate-compile || fail 'write path field missing'
grep -q 'parse_syscall_file_paths' bin/queue-interrogate-compile || fail 'syscall file path parser missing'
echo '[PASS] interrogation file path review static checks pass'
