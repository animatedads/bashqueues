#!/usr/bin/env bash
set -euo pipefail

src_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/qroot"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_PLUGIN_SOURCE_DIR="$src_root/assets.d"
export QUEUEBASH_CAP_PLUGIN_SOURCE_DIR="$src_root/caps.d"
export QUEUEBASH_CLASS_SOURCE_DIR="$src_root/classes"
export QUEUEBASH_POLICY_SOURCE_DIR="$src_root/policies.d"
export QUEUEBASH_REPORTER_PLUGIN_SOURCE_DIR="$src_root/reporters.d"

source "$src_root/queuebash.sh"
queue list >/dev/null

json="$(queue reporters list --json)"
printf '%s\n' "$json" | grep -q 'snmp:inform'
[[ -f "$QUEUEBASH_ROOT/reporters.d/snmp.sh" ]]

mkdir -p "$QUEUEBASH_ROOT/reporters.d"
cat > "$QUEUEBASH_ROOT/reporters.d/record.sh" <<'PLUGIN'
#!/usr/bin/env bash
queue_reporter_facilities() { printf 'record:file\tRecords queue events to a file\n'; }
queue_reporter_handle_event() {
    printf '%s|%s|%s|%s|%s\n' "$1" "$2" "$3" "$4" "$5" >> "${QUEUEBASH_REPORT_TEST_FILE:?}"
}
PLUGIN
chmod +x "$QUEUEBASH_ROOT/reporters.d/record.sh"

export QUEUEBASH_REPORTERS=record
export QUEUEBASH_REPORTING_SYNC=1
export QUEUEBASH_REPORT_TEST_FILE="$tmp/events.recorded"
_queue_log_event "unit_event" "qid1" "job-one" "pol_blocked" "detail=ok"
grep -q 'unit_event|qid1|job-one|pol_blocked|detail=ok' "$QUEUEBASH_REPORT_TEST_FILE"

unset QUEUEBASH_REPORTERS
: > "$QUEUEBASH_REPORT_TEST_FILE"
_queue_log_event "unit_event2" "qid2" "job-two" "failed" "detail=no"
[[ ! -s "$QUEUEBASH_REPORT_TEST_FILE" ]]

[[ ! -e "$src_root/assets.d/net_usage.sh" ]]
echo '[PASS] reporting plugin list and explicit event observer dispatch work'
