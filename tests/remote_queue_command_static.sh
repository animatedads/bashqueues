#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -Eq 'QUEUEBASH_VERSION="0\.18\.(33|34|35|36|37|38|39|40|41|42|43|44|45|46|47|48|49|([5-9][0-9]|[1-9][0-9][0-9]))"' queuebash.sh || fail 'version not bumped to 0.18.31 or newer'
grep -q '0.18.35 - APAC/China cloud provider contracts' CHANGELOG.md || fail 'CHANGELOG 0.18.31 entry missing'
grep -q '0.18.35 APAC/China cloud provider contracts' README.md || fail 'README 0.18.31 entry missing'

grep -q '_queue_remote_command' queuebash.sh || fail 'queue remote command function missing'
grep -q 'remote|remote-queue|rq)' queuebash.sh || fail 'queue dispatcher lacks remote command branch'
grep -q 'queue remote list' docs/REMOTE_QUEUE_COMMAND.md || fail 'remote docs lack remote list usage'
grep -q 'queue remote add SERVICE --url URL' docs/REMOTE_QUEUE_COMMAND.md || fail 'remote add docs missing'
grep -q 'def add_service' bin/queue-remote-service-client.py || fail 'remote add implementation missing'
grep -q 'QUEUE_REMOTE_CONFIG_DIR' bin/queue-remote-service-client.py || fail 'remote add config dir support missing'
grep -q 'QUEUE_REMOTE_SECRET_DIR' bin/queue-remote-service-client.py || fail 'remote add secret dir support missing'

for f in bin/queue-remote-service-client.py docs/REMOTE_QUEUE_COMMAND.md examples/remote.d/oci-node-b.env.example; do
  [[ -f "$f" ]] || fail "missing $f"
done

python3 -m py_compile bin/queue-remote-service-client.py || fail 'remote service client py_compile failed'

grep -q 'queuebash.remote_queue_request.v1' docs/REMOTE_QUEUE_COMMAND.md || fail 'request schema missing from docs'
grep -q 'QUEUE_REMOTE_SECRET_FILE' docs/REMOTE_QUEUE_COMMAND.md || fail 'secret file config missing from docs'
grep -q -- '--dry-run' docs/REMOTE_QUEUE_COMMAND.md || fail 'remote add dry-run docs missing'
grep -q -- '--secret-file' docs/REMOTE_QUEUE_COMMAND.md || fail 'remote add secret-file docs missing'
grep -q 'No returned value is evaluated as shell\|never evaluated as shell' docs/REMOTE_QUEUE_COMMAND.md docs/REMOTE_QUEUE_SERVICE_PROVIDER.md || fail 'shell evaluation ban missing'
grep -q 'run.*exec.*shell.*command.*cmd' docs/REMOTE_QUEUE_COMMAND.md || fail 'blocked alias list missing'

grep -q 'QUEUE_REMOTE_URL=' examples/remote.d/oci-node-b.env.example || fail 'example URL missing'
grep -q 'QUEUE_REMOTE_ENDPOINT=/remote-queue' examples/remote.d/oci-node-b.env.example || fail 'example endpoint missing'
grep -q 'QUEUE_REMOTE_SECRET_FILE=' examples/remote.d/oci-node-b.env.example || fail 'example secret file missing'
grep -q 'QUEUE_REMOTE_ALLOW_RAW_OPERATIONS=0' examples/remote.d/oci-node-b.env.example || fail 'raw operations must default off'

if grep -Eq 'subprocess\.|os\.system|shell=True|/bin/sh|bash -c|eval\(|exec\(' bin/queue-remote-service-client.py; then
  fail 'remote client must not execute local shell commands'
fi

if grep -R '/etc/bashqueues' docs/REMOTE_QUEUE_COMMAND.md examples/remote.d/oci-node-b.env.example >/dev/null; then
  fail 'remote command docs/examples must not introduce /etc/bashqueues namespace drift'
fi

[[ ! -e assets.d/net_usage.sh ]] || fail 'assets.d/net_usage.sh must remain absent'
[[ -f caps.d/net_usage.sh ]] || fail 'caps.d/net_usage.sh expected to remain present'

echo '[PASS] remote queue command static checks pass'
