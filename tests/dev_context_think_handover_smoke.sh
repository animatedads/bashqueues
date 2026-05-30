#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp queuebash.sh "$tmp/queuebash.sh"
(
  cd "$tmp"
  export QUEUEBASH_ROOT="$tmp/.queuebash"
  export QUEUEBASH_ALLOW_NONINTERACTIVE=1
  source ./queuebash.sh

  ctx="$(queue dev context --json --limit 5)"
  QB_JSON="$ctx" python3 - <<'PY'
import json, os
d=json.loads(os.environ['QB_JSON'])
assert d['schema']=='queuebash.dev_workflow.context.v1'
assert d['status']=='ok'
assert d['mode']=='working_set'
PY

  think="$(queue dev think --text 'plan bounded context smoke' --subject smoke --tag bob12 --json)"
  QB_JSON="$think" python3 - <<'PY'
import json, os
d=json.loads(os.environ['QB_JSON'])
assert d['schema']=='queuebash.dev_workflow.think.v1'
assert d['status']=='ok'
assert d['item_id'].startswith('DEVTHINK-')
assert 'bob12' in d['tags']
PY

  ctx2="$(queue dev context --json --tag bob12)"
  QB_JSON="$ctx2" python3 - <<'PY'
import json, os
d=json.loads(os.environ['QB_JSON'])
assert d['schema']=='queuebash.dev_workflow.context.v1'
assert d['counts']['returned_items'] >= 1
PY

  hand="$(queue dev handover --json --tag bob12)"
  QB_JSON="$hand" python3 - <<'PY'
import json, os
d=json.loads(os.environ['QB_JSON'])
assert d['schema']=='queuebash.dev_workflow.handover.v1'
assert d['status']=='ok'
assert d['mode']=='delta'
assert 'changed_files' in d and 'open_tasks' in d and 'known_landmines' in d
PY
)

echo PASS dev_context_think_handover_smoke
