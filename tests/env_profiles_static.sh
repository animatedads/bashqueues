#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -q 'QUEUEBASH_VERSION="0.18.0"' queuebash.sh || fail "version not bumped to 0.17.95"
grep -q '_queue_env_command' queuebash.sh || fail "env command missing"
grep -q '_queue_install_bundled_env_profiles' queuebash.sh || fail "bundled env installer missing"
grep -q 'CLASS_EXEC_ENV' queuebash.sh || fail "CLASS_EXEC_ENV default handling missing"
grep -q 'env:profile_required' assets.d/env.sh || fail "env asset missing profile_required"
grep -q 'CLASS_EXEC_ENV=test' classes/ENV_TEST.env || fail "ENV_TEST class missing CLASS_EXEC_ENV"
grep -q 'CLASS_EXEC_ENV=live' classes/ENV_LIVE.env || fail "ENV_LIVE class missing CLASS_EXEC_ENV"
[[ -f envs.d/test.env && -f envs.d/live.env && -f envs.d/staging.env ]] || fail "bundled env profiles missing"
[[ ! -e assets.d/net_usage.sh ]] || fail "assets.d/net_usage.sh must remain absent"

echo "[PASS] execution environment static checks pass"
