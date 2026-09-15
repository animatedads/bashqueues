#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="${TMPDIR:-/tmp}/queuebash-rto-feature-registry-smoke.$$"
rm -rf "$QUEUEBASH_ROOT"
source ./queuebash.sh

queue rto status --json | python3 -m json.tool >/dev/null
queue rto features --json > "$QUEUEBASH_ROOT.rto_features.json"
python3 - "$QUEUEBASH_ROOT.rto_features.json" <<'PY'
import json, sys
j=json.load(open(sys.argv[1]))
assert j['schema']=='queuebash.rto.feature_registry.v1'
assert j['available'] is True
assert j['context_bundle']=='rto.v66.catalog+object-tree+roles+resources'
ids={f['feature_id'] for f in j['features']}
for required in ['check-free-drive-space','check-drive-health','check-mysql-database']:
    assert required in ids, (required, ids)
assert any(a.get('trust_family')=='check-drive-space' for a in j.get('allowed', []))
PY

set +e
queue ask --context rto --json 'plan a windows vm deployment with preflight receipts using rto' > "$QUEUEBASH_ROOT.rto_ask.json"
ask_rc=$?
set -e
[[ "$ask_rc" -eq 0 ]]
python3 - "$QUEUEBASH_ROOT.rto_ask.json" <<'PY'
import json, sys
j=json.load(open(sys.argv[1]))
r=j['rto']
assert r['available'] is True
assert r['relevant'] is True
assert r['context_bundle']=='rto.v66.catalog+object-tree+roles+resources'
assert r['plan_id_required'] is True
cmds=' '.join(r['suggested_commands'])
assert 'rto plan deploy' in cmds
assert 'rto plan preflight' in cmds
assert 'latest' not in cmds
fr=r['feature_registry']
ids={f['feature_id'] for f in fr['features']}
assert 'check-free-drive-space' in ids
assert 'receipts' in (j.get('dynamic_context_text') or '').lower()
assert 'plan/preflight/receipt' in (j.get('dynamic_context_text') or '').lower()
assert 'context bundle' in (j.get('dynamic_context_text') or '').lower()
PY

queue rto catalog > "$QUEUEBASH_ROOT.rto_catalog.txt"
grep -q 'check-free-drive-space' "$QUEUEBASH_ROOT.rto_catalog.txt"
queue rto allowed > "$QUEUEBASH_ROOT.rto_allowed.txt"
grep -q 'check-drive-space' "$QUEUEBASH_ROOT.rto_allowed.txt"

rm -rf "$QUEUEBASH_ROOT" "$QUEUEBASH_ROOT.rto_features.json" "$QUEUEBASH_ROOT.rto_ask.json" "$QUEUEBASH_ROOT.rto_catalog.txt" "$QUEUEBASH_ROOT.rto_allowed.txt"
echo "rto_feature_registry_ask_smoke: ok"
