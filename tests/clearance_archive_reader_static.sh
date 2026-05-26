#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -q 'QUEUEBASH_VERSION="0.17.92"' queuebash.sh || fail "version not bumped to 0.17.92"
grep -q 'QUEUE_CLEARED_ARCHIVED' queuebash.sh || fail "archive metadata not referenced"
grep -q 'JOB_CLEARED.*QUEUE_CLEARED_ARCHIVED' queuebash.sh || fail "cleared audit does not accept archived records"
grep -q -- '--no-changelog' queuebash.sh || fail "queue dev comment lacks --no-changelog override"
grep -q 'changelog=1' queuebash.sh || fail "queue dev comment does not default changelog on"
grep -q '0.17.92 - profile signature verification' CHANGELOG.md || fail "changelog entry missing"
[[ ! -e assets.d/net_usage.sh ]] || fail "assets.d/net_usage.sh must remain absent"

echo '[PASS] clearance archive reader/dev changelog static checks pass'
