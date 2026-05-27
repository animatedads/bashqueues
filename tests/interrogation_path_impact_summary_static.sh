#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -q 'QUEUEBASH_VERSION="0.18.11"' queuebash.sh || fail 'version not bumped to 0.18.11'
grep -q 'PROFILE_EFFECTIVE_USER' bin/queue-interrogate || fail 'effective user not captured'
grep -q 'PROFILE_ENV_USER' bin/queue-interrogate || fail 'env user not captured'
grep -q 'def path_impact_summary' bin/queue-interrogate-compile || fail 'path impact helper missing'
grep -q 'FILEPROFILE_PATH_IMPACT=' bin/queue-interrogate-compile || fail 'file profile path impact not emitted'
grep -q 'effective_users:' bin/queue-interrogate-compile || fail 'explain does not display effective users'
grep -q 'path impact:' bin/queue-interrogate-compile || fail 'explain does not display path impact'
grep -q '0.17.93 - Ed25519 profile signing' CHANGELOG.md || fail 'changelog entry missing'

echo '[PASS] interrogation path impact/effective user static checks pass'
