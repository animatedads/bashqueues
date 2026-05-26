#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$root"

grep -Eq 'QUEUEBASH_VERSION="0\.[0-9]+\.[0-9]+"' queuebash.sh
[[ -x reporters.d/ms.sh ]]
grep -q 'queue_reporter_handle_event()' reporters.d/ms.sh
grep -q 'ms:notify' reporters.d/ms.sh
grep -q 'QUEUEBASH_MS_ENDPOINT' policies.d/reporting/default.env
grep -q 'Microsoft Notify reporter' docs/REPORTING_PLUGINS.md

if grep -E 'printf .*client_secret|printf .*Bearer|127\.0\.0\.1' reporters.d/ms.sh 2>/dev/null; then
    echo '[FAIL] Microsoft reporter must not hard-code secrets, bearer tokens, or localhost defaults' >&2
    exit 1
fi
if [[ -e assets.d/net_usage.sh ]]; then
    echo '[FAIL] assets.d/net_usage.sh must remain absent' >&2
    exit 1
fi

bash -n reporters.d/ms.sh

echo '[PASS] Microsoft reporter static surface present and net_usage asset absent'
