#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp queuebash.sh "$tmp/queuebash.sh"
(
  cd "$tmp"
  export QUEUEBASH_ALLOW_NONINTERACTIVE=1
  export QUEUEBASH_ROOT="$tmp/.queuebash"
  source ./queuebash.sh
  aid="$(queue dev attempt begin --text 'smoke attempt' --tag bob12 --based-on SP-EXAMPLE --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["attempt_id"])')"
  [[ "$aid" == DEVATTEMPT-* ]]
  eid="$(queue dev evidence record --attempt "$aid" --text 'syntax check passed' --command 'bash -n queuebash.sh' --file queuebash.sh --status pass --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["evidence_id"])')"
  [[ "$eid" == DEVEVIDENCE-* ]]
  queue dev attempt end "$aid" --status resolved --text 'smoke complete' --json > "$tmp/end.json"
  python3 - "$tmp/.queuebash/dev/attempts.json" "$aid" "$eid" <<'PY'
import json,sys
p,aid,eid=sys.argv[1:]
d=json.load(open(p))
assert d['schema']=='queuebash.dev_workflow.attempt_store.v1'
a=[x for x in d['attempts'] if x['attempt_id']==aid][0]
assert a['status']=='resolved'
assert eid in a['evidence']
e=[x for x in d['evidence'] if x['evidence_id']==eid][0]
assert e['attempt_id']==aid
assert e['files'][0]['md5']
assert e['commands']==['bash -n queuebash.sh']
PY
)
echo 'PASS dev_attempt_evidence_smoke'
