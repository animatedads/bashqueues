#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)"
cd "$ROOT_DIR"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="${TMPDIR:-/tmp}/bq-rto-boundary-$$"
rm -rf "$QUEUEBASH_ROOT"
# shellcheck source=/dev/null
source ./queuebash.sh

queue rto features --json > /tmp/bq-rto-features-$$.json
python3 - /tmp/bq-rto-features-$$.json <<'PY'
import json,sys
j=json.load(open(sys.argv[1]))
assert j['schema'] == 'queuebash.rto.feature_registry.v1'
assert 'operation_boundary' in j
assert 'read_check_operations' in j
assert any(op.get('operation_id') == 'check-free-drive-space' for op in j['read_check_operations'])
PY

queue rto operations service --json > /tmp/bq-rto-ops-$$.json
python3 - /tmp/bq-rto-ops-$$.json <<'PY'
import json,sys
j=json.load(open(sys.argv[1]))
assert j.get('schema') in ('queuebash.rto.wrapper.v1','alchemy.rto.operations.v1')
text=json.dumps(j)
assert 'operation_boundary' in text or 'features' in text
PY

set +e
queue ask --context rto --json 'Can RTO list running services on a linux server?' > /tmp/bq-rto-ask-$$.json
ask_rc=$?
set -e
if [[ "$ask_rc" -ne 0 ]]; then
  echo "queue ask returned rc=$ask_rc" >&2
  cat /tmp/bq-rto-ask-$$.json >&2 || true
  exit 1
fi
python3 - /tmp/bq-rto-ask-$$.json <<'PY'
import json,sys
j=json.load(open(sys.argv[1]))
text=json.dumps(j)
assert j['rto']['available'] is True
assert j['rto']['relevant'] is True
assert 'operation_boundary' in text
assert 'do_not_recommend_rto_plan_for_read_only_checks' in text
assert 'queue rto operations service' in text
assert 'queue rto provider select list-running-services linux linux-service-inventory' in text
assert 'queue rto explain check services linux-service-inventory' in text
assert 'queue rto plan deploy service-status' not in text
assert 'rto plan deploy service-status' not in text
PY

rm -f /tmp/bq-rto-features-$$.json /tmp/bq-rto-ops-$$.json /tmp/bq-rto-ask-$$.json
rm -rf "$QUEUEBASH_ROOT"
echo "rto_ask_operation_boundary_smoke: ok"
