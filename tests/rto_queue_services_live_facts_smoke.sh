#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="${QUEUEBASH_ROOT:-/tmp/bq-rto-queue-services-smoke-$$}"
source "$ROOT/queuebash.sh"

json_ok() { python3 -m json.tool >/dev/null; }

queue identity whoami --json | json_ok
queue roles --json | json_ok
queue consistency --json | json_ok
queue cluster --json | json_ok
queue cloud status --json | json_ok
queue cloud billing --json | json_ok
queue cloud cost --json | json_ok
queue rto queue-services --json | json_ok

queue rto queue-services --json > /tmp/rto_queue_services_$$.json
python3 - /tmp/rto_queue_services_$$.json <<'PY'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    j=json.load(f)
assert j['schema']=='queuebash.rto.queue_services.v1'
services=j['services']
for name in ['policy','enterprise','cluster','identity','cloud','costs','consistency']:
    assert name in services, name
assert services['policy']['live'] is True
assert services['identity']['live'] is True
assert services['consistency']['live'] is True
assert services['cloud']['live'] is False
assert services['costs']['live'] is False
assert j['snapshots']['cloud_status']['network_touched'] is False
assert j['snapshots']['consistency']['waiting_recheck_supported'] is True
PY
rm -f /tmp/rto_queue_services_$$.json

printf 'PASS rto_queue_services_live_facts_smoke\n'
