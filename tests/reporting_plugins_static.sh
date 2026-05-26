#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$root"

grep -q 'QUEUEBASH_VERSION="0.17.66"' queuebash.sh
for fn in _queue_install_bundled_reporter_plugins _queue_report_event _queue_reporter_scan _queue_reporters_list_json _queue_reporting_source_config; do
    grep -q "^[[:space:]]*$fn()" queuebash.sh
 done

grep -q 'reporters|reporting)' queuebash.sh
grep -q 'reporters.d' install-system.sh
[[ -x reporters.d/snmp.sh ]]
grep -q 'queue_reporter_handle_event()' reporters.d/snmp.sh
grep -q 'QUEUEBASH_SNMP_INFORM_DEST' reporters.d/snmp.sh
grep -q 'QUEUEBASH_REPORTERS' policies.d/reporting/default.env

if grep -R 'QUEUEBASH_SNMP_COMMUNITY="alerts"\|127\.0\.0\.1' reporters.d policies.d docs 2>/dev/null; then
    echo '[FAIL] reporting must not hard-code local NMS destination or alerts community' >&2
    exit 1
fi
if [[ -e assets.d/net_usage.sh ]]; then
    echo '[FAIL] assets.d/net_usage.sh must remain absent' >&2
    exit 1
fi

echo '[PASS] reporting plugin static surface present and net_usage asset absent'
