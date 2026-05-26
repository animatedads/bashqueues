#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -q 'PROFILE_CAPTURED_UID' bin/queue-interrogate || fail 'queue-interrogate does not stamp PROFILE_CAPTURED_UID'
grep -q 'PROFILE_CAPTURED_QUEUE_ROOT' bin/queue-interrogate || fail 'queue-interrogate does not stamp queue root'
grep -q 'PROFILE_PRIVILEGED_CONTEXT' bin/queue-interrogate || fail 'queue-interrogate does not stamp privileged context'
grep -q 'privileged_profile_requires_review' bin/queue-interrogate-compile || fail 'compiler does not gate privileged profiles'
grep -q 'root_profile_requires_review' bin/queue-interrogate-compile || fail 'compiler does not gate root profiles'
grep -q 'privilege context:' bin/queue-interrogate-compile || fail 'explain does not display privilege context'
grep -q 'QUEUEBASH_VERSION="0.17.92"' queuebash.sh || fail 'queuebash version not 0.17.92'

echo '[PASS] interrogation privilege context static checks pass'
