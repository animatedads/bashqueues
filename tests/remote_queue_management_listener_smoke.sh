#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "[FAIL] $*" >&2; exit 1; }

root="$(mktemp -d)"
cleanup(){
  if [[ -n "${listener_pid:-}" ]]; then kill "$listener_pid" 2>/dev/null || true; wait "$listener_pid" 2>/dev/null || true; fi
  rm -rf "$root"
}
trap cleanup EXIT

mkdir -p "$root/policy/secrets" "$root/client-remote.d" "$root/state" "$root/log" "$root/qroot"
printf '%s\n' 'remote-test-secret' > "$root/policy/secrets/admin.secret"
chmod 0640 "$root/policy/secrets/admin.secret"
cat > "$root/policy/clients.tsv" <<TSV
queue-admin	default	queue-admin@example.invalid	$root/policy/secrets/admin.secret	active	smoke test client
TSV
cat > "$root/policy/acl.tsv" <<'TSV'
queue-admin@example.invalid	health	*	allow	health allowed
queue-admin@example.invalid	version	*	allow	version allowed
TSV
cat > "$root/policy/remote-management.env" <<EOFENV
QUEUE_REMOTE_MANAGEMENT_HOST=127.0.0.1
QUEUE_REMOTE_MANAGEMENT_PORT=18765
QUEUE_REMOTE_MANAGEMENT_ENDPOINT=/remote-queue
QUEUE_REMOTE_MANAGEMENT_LOOPBACK_ONLY=1
QUEUE_REMOTE_MANAGEMENT_QUEUEBASH_SOURCE=$PWD/queuebash.sh
QUEUE_REMOTE_MANAGEMENT_QUEUE_ROOT=$root/qroot
QUEUE_REMOTE_MANAGEMENT_CLIENTS_FILE=$root/policy/clients.tsv
QUEUE_REMOTE_MANAGEMENT_ACL_FILE=$root/policy/acl.tsv
QUEUE_REMOTE_MANAGEMENT_STATE_DIR=$root/state
QUEUE_REMOTE_MANAGEMENT_AUDIT_LOG=$root/log/audit.jsonl
QUEUE_REMOTE_MANAGEMENT_MAX_RUNTIME_SECONDS=5
EOFENV
cat > "$root/client-remote.d/local.env" <<EOFCLIENT
QUEUE_REMOTE_URL=http://127.0.0.1:18765
QUEUE_REMOTE_ENDPOINT=/remote-queue
QUEUE_REMOTE_CLIENT_ID=queue-admin
QUEUE_REMOTE_KEY_ID=default
QUEUE_REMOTE_SECRET_FILE=$root/policy/secrets/admin.secret
QUEUE_REMOTE_REQUEST_TTL_SECONDS=60
QUEUE_REMOTE_HTTP_TIMEOUT_SECONDS=5
EOFCLIENT

python3 bin/queue-remote-management-listener.py --config "$root/policy/remote-management.env" >"$root/listener.out" 2>"$root/listener.err" &
listener_pid=$!
for _ in $(seq 1 50); do
  if python3 - <<'PY' >/dev/null 2>&1
import urllib.request
urllib.request.urlopen('http://127.0.0.1:18765/healthz', timeout=0.2).read()
PY
  then break; fi
  sleep 0.1
done
python3 - <<'PY'
import urllib.request
urllib.request.urlopen('http://127.0.0.1:18765/healthz', timeout=2).read()
PY

QUEUE_REMOTE_CONFIG_DIR="$root/client-remote.d" python3 bin/queue-remote-service-client.py local health --json > "$root/health.json"
python3 - "$root/health.json" <<'PY'
import json, sys
d=json.load(open(sys.argv[1]))
assert d['schema']=='queuebash.remote_queue_service.v1'
assert d['operation']=='health'
assert d['status']=='ok'
assert d['decision']=='allow'
assert d['subject']=='queue-admin@example.invalid'
assert d['result']['health']=='ok'
PY

QUEUE_REMOTE_CONFIG_DIR="$root/client-remote.d" python3 bin/queue-remote-service-client.py local capabilities --json > "$root/capabilities.json" || denied=$?
: "${denied:=0}"
[[ "$denied" != 0 ]] || fail 'capabilities unexpectedly allowed without ACL grant'
python3 - "$root/capabilities.json" <<'PY'
import json, sys
d=json.load(open(sys.argv[1]))
assert d['status']=='forbidden'
assert d['decision']=='deny'
assert d['reason']=='no_matching_remote_queue_acl_rule'
PY

cat > "$root/client-remote.d/bad.env" <<EOFBAD
QUEUE_REMOTE_URL=http://127.0.0.1:18765
QUEUE_REMOTE_ENDPOINT=/remote-queue
QUEUE_REMOTE_CLIENT_ID=queue-admin
QUEUE_REMOTE_KEY_ID=default
QUEUE_REMOTE_SHARED_SECRET=wrong-secret
QUEUE_REMOTE_REQUEST_TTL_SECONDS=60
QUEUE_REMOTE_HTTP_TIMEOUT_SECONDS=5
EOFBAD
timeout 10 env QUEUE_REMOTE_CONFIG_DIR="$root/client-remote.d" python3 bin/queue-remote-service-client.py bad health --json > "$root/bad.json" || bad_rc=$?
: "${bad_rc:=0}"
[[ "$bad_rc" != 0 ]] || fail 'bad signature unexpectedly accepted'
[[ "$bad_rc" != 124 ]] || fail 'bad signature request timed out instead of returning bounded denial'
python3 - "$root/bad.json" <<'PY'
import json, sys
d=json.load(open(sys.argv[1]))
assert d['status']=='error'
assert d['decision']=='deny'
assert 'signature' in d['reason']
PY

cat > "$root/client-remote.d/unknown.env" <<EOFUNKNOWN
QUEUE_REMOTE_URL=http://127.0.0.1:18765
QUEUE_REMOTE_ENDPOINT=/remote-queue
QUEUE_REMOTE_CLIENT_ID=unknown-client
QUEUE_REMOTE_KEY_ID=default
QUEUE_REMOTE_SHARED_SECRET=remote-test-secret
QUEUE_REMOTE_REQUEST_TTL_SECONDS=60
QUEUE_REMOTE_HTTP_TIMEOUT_SECONDS=5
EOFUNKNOWN
timeout 10 env QUEUE_REMOTE_CONFIG_DIR="$root/client-remote.d" python3 bin/queue-remote-service-client.py unknown health --json > "$root/unknown.json" || unknown_rc=$?
: "${unknown_rc:=0}"
[[ "$unknown_rc" != 0 ]] || fail 'unknown client unexpectedly accepted'
[[ "$unknown_rc" != 124 ]] || fail 'unknown client request timed out instead of returning bounded denial'
python3 - "$root/unknown.json" <<'PY'
import json, sys
d=json.load(open(sys.argv[1]))
assert d['status']=='error'
assert d['decision']=='deny'
assert 'registered' in d['reason']
PY

grep -q '"operation":"health"' "$root/log/audit.jsonl" || fail 'audit log missing health event'
grep -q '"decision":"deny"' "$root/log/audit.jsonl" || fail 'audit log missing deny event'

echo '[PASS] remote queue management listener smoke checks pass'
