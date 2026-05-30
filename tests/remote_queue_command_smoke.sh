#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/queue-remote-command-smoke.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
secret='smoke-secret-not-for-production'
mkdir -p "$tmp/remote.d" "$tmp/queue-root/classes"
printf '%s\n' "$secret" > "$tmp/secret"
cat > "$tmp/remote.d/smoke.env" <<EOF
QUEUE_REMOTE_SERVICE=smoke
QUEUE_REMOTE_URL=http://127.0.0.1:9
QUEUE_REMOTE_ENDPOINT=/remote-queue
QUEUE_REMOTE_CLIENT_ID=smoke-client
QUEUE_REMOTE_KEY_ID=smoke-key
QUEUE_REMOTE_SECRET_FILE=$tmp/secret
QUEUE_REMOTE_REQUEST_TTL_SECONDS=60
QUEUE_REMOTE_HTTP_TIMEOUT_SECONDS=1
EOF
cat > "$tmp/queue-root/classes/DEFAULT.env" <<'EOF_DEFAULT'
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
CLASS_DEFAULT_RUNNER=direct
EOF_DEFAULT

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$tmp/queue-root"
export QUEUE_REMOTE_CONFIG_DIR="$tmp/remote.d"
client=(python3 bin/queue-remote-service-client.py)

"${client[@]}" add local-management --url 127.0.0.1:8765 --endpoint /remote-queue --client-id queue-admin --key-id default --secret add-secret --secret-dir "$tmp/secrets" --json > "$tmp/add.json"
python3 - "$tmp/add.json" <<'PY'
import json, sys
obj=json.load(open(sys.argv[1]))
assert obj['schema']=='queuebash.remote_queue_client.v1'
assert obj['operation']=='add'
assert obj['service']=='local-management'
assert obj['status']=='created'
assert obj['url']=='http://127.0.0.1:8765'
assert 'add-secret' not in json.dumps(obj)
PY
[[ -f "$tmp/remote.d/local-management.env" ]] || fail 'remote add did not create service env'
[[ -f "$tmp/secrets/local-management.secret" ]] || fail 'remote add did not create secret file'
grep -q 'QUEUE_REMOTE_URL=http://127.0.0.1:8765' "$tmp/remote.d/local-management.env" || fail 'remote add URL missing'
grep -q 'QUEUE_REMOTE_SECRET_FILE=' "$tmp/remote.d/local-management.env" || fail 'remote add secret file missing'
"${client[@]}" show local-management --json > "$tmp/add-show.json"
grep -q '<redacted>' "$tmp/add-show.json" || fail 'remote add show must redact secret-bearing fields'

"${client[@]}" list --json > "$tmp/list.json"
python3 - "$tmp/list.json" <<'PY'
import json, sys
obj=json.load(open(sys.argv[1]))
assert obj['schema']=='queuebash.remote_queue_client.v1'
assert any(x['name']=='smoke' for x in obj['services'])
PY

"${client[@]}" show smoke --json > "$tmp/show.json"
grep -q '<redacted>' "$tmp/show.json" || fail 'show must redact secret-bearing fields'

if "${client[@]}" smoke run --json >"$tmp/run.out" 2>"$tmp/run.err"; then
  fail 'queue remote run must be rejected by client guard'
fi
grep -q 'not exposed\|denied\|unknown' "$tmp/run.err" || fail 'run rejection message missing'

echo '[PASS] remote queue command smoke checks pass'
