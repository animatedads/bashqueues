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

mkdir -p "$tmp/bin"
cat > "$tmp/bin/curl" <<'FAKECURL'
#!/usr/bin/env bash
set -euo pipefail
args="$*"
if [[ "$args" == *login.microsoftonline.com* ]]; then
    printf '{"access_token":"fake-token-123"}\n'
    exit 0
fi
out="${QUEUEBASH_MS_CURL_CAPTURE:?}"
printf '%s\n' "$args" >> "$out.args"
# Last argument is endpoint in this reporter call.
printf '%s\n' "${@: -1}" >> "$out.endpoint"
# Capture -d payload.
prev=""
for a in "$@"; do
    if [[ "$prev" == "-d" ]]; then
        printf '%s\n' "$a" >> "$out.payload"
    fi
    prev="$a"
done
exit 0
FAKECURL
chmod +x "$tmp/bin/curl"
export PATH="$tmp/bin:$PATH"
export QUEUEBASH_MS_CURL_CAPTURE="$tmp/ms"

source "$src_root/queuebash.sh"
queue list >/dev/null

json="$(queue reporters list --json)"
printf '%s\n' "$json" | grep -q 'ms:notify'
[[ -f "$QUEUEBASH_ROOT/reporters.d/ms.sh" ]]

printf 'not-a-real-secret\n' > "$tmp/secret"
export QUEUEBASH_REPORTERS=ms
export QUEUEBASH_REPORTING_SYNC=1
export QUEUEBASH_MS_ENDPOINT='https://example.ingest.monitor.azure.com/queuebash'
export QUEUEBASH_MS_TENANT='tenant-example'
export QUEUEBASH_MS_CLIENT_ID='client-example'
export QUEUEBASH_MS_CLIENT_SECRET_FILE="$tmp/secret"
export QUEUEBASH_MS_EVENTS='failed,pol_blocked'
export QUEUEBASH_MS_TABLE='QueuebashEventTest'

_queue_log_event 'unit_event' 'qid-skip' 'job-skip' 'done' 'detail=skip'
[[ ! -e "$tmp/ms.payload" ]]

_queue_log_event 'unit_event' 'qid-ms' 'job-ms' 'pol_blocked' 'detail=ok'
grep -q 'https://example.ingest.monitor.azure.com/queuebash' "$tmp/ms.endpoint"
grep -q 'Authorization: Bearer fake-token-123' "$tmp/ms.args"
grep -q 'QueuebashEventTest' "$tmp/ms.payload"
grep -q 'qid-ms' "$tmp/ms.payload"
grep -q 'pol_blocked' "$tmp/ms.payload"

if [[ -f "$QUEUEBASH_ROOT/logs/reporters.err" ]] && grep -q 'not-a-real-secret\|fake-token-123' "$QUEUEBASH_ROOT/logs/reporters.err"; then
    echo '[FAIL] Microsoft reporter leaked secret material to reporters.err' >&2
    exit 1
fi
[[ ! -e "$src_root/assets.d/net_usage.sh" ]]

echo '[PASS] Microsoft reporter discovery and explicit event dispatch work'
