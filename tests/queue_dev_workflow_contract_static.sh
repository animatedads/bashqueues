#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail(){ echo "FAIL: $*" >&2; exit 1; }

[[ -f queuebash.sh ]] || fail 'run from repository root'
grep -Eq 'QUEUEBASH_VERSION="0\.18\.(43|44|4[5-9]|[5-9][0-9])"' queuebash.sh || fail 'queuebash version must preserve 0.18.43+ workflow contract line'
grep -Eq '^#{1,2} 0.18.43 BOB12 dev workflow command contracts' README.md || fail 'README missing 0.18.43 workflow contract entry'
grep -q '^## 0.18.43 - BOB12 dev workflow command contracts' CHANGELOG.md || fail 'CHANGELOG missing 0.18.43 workflow contract entry'

[[ -f docs/QUEUE_DEV_WORKFLOW_COMMANDS.md ]] || fail 'missing workflow command contract doc'
[[ -f docs/QUEUE_DEV_WORKFLOW_SCHEMAS.md ]] || fail 'missing workflow schema doc'
[[ -f docs/QUEUE_DEV_WORKFLOW_SECURITY_MODEL.md ]] || fail 'missing workflow security model doc'
[[ -f tests/queue_dev_workflow_json_contract_static.py ]] || fail 'missing workflow JSON contract static test'

for cmd in \
  'queue dev context' \
  'queue dev think' \
  'queue dev attempt begin' \
  'queue dev attempt end' \
  'queue dev evidence record' \
  'queue dev handover' \
  'queue dev scratchpad status set' \
  'queue dev scratchpad supersede'; do
  grep -q "$cmd" docs/QUEUE_DEV_WORKFLOW_COMMANDS.md || fail "workflow contract missing $cmd"
  grep -q "$cmd" docs/QUEUE_DEV_WORKFLOW_SCHEMAS.md || fail "workflow schemas missing $cmd"
done

for schema in \
  queuebash.dev_workflow.context.v1 \
  queuebash.dev_workflow.think.v1 \
  queuebash.dev_workflow.attempt.v1 \
  queuebash.dev_workflow.evidence.v1 \
  queuebash.dev_workflow.handover.v1 \
  queuebash.dev_workflow.scratchpad_status.v1 \
  queuebash.dev_workflow.supersede.v1; do
  grep -q "$schema" docs/QUEUE_DEV_WORKFLOW_COMMANDS.md || fail "workflow commands missing schema $schema"
  grep -q "$schema" docs/QUEUE_DEV_WORKFLOW_SCHEMAS.md || fail "workflow schemas missing schema $schema"
done

grep -q 'contract-first roadmap' docs/QUEUE_DEV_WORKFLOW_COMMANDS.md || fail 'contract-first boundary missing'
grep -q 'proposed contracts only' docs/QUEUE_DEV_WORKFLOW_COMMANDS.md || fail 'non-implementation boundary missing'
grep -q 'only the scratchpad lifecycle handlers' docs/QUEUE_DEV_WORKFLOW_COMMANDS.md || fail 'staged implementation statement missing'
grep -q 'does not add dynamic JSON probes' docs/QUEUE_DEV_WORKFLOW_COMMANDS.md || fail 'dynamic probe boundary missing'
grep -q 'working-set default unless --full-corpus is explicit' docs/QUEUE_DEV_WORKFLOW_COMMANDS.md || fail 'working set default missing'
grep -q 'Validation output is evidence, not authority' docs/QUEUE_DEV_WORKFLOW_SECURITY_MODEL.md || fail 'validation authority boundary missing'
grep -q 'must not introduce `exec`, `shell`, `bash`, `cmd`' docs/QUEUE_DEV_WORKFLOW_SECURITY_MODEL.md || fail 'no shell boundary missing'

# This package intentionally does not wire handlers yet.
! grep -q '_queue_dev_workflow_context' queuebash.sh || fail 'unexpected workflow context implementation present'
! grep -q 'context) _queue_dev_workflow_context' queuebash.sh || fail 'unexpected context dispatcher branch present'

! [[ -e assets.d/net_usage.sh ]] || fail 'assets.d/net_usage.sh must remain absent'
[[ -e caps.d/net_usage.sh ]] || fail 'caps.d/net_usage.sh should remain present'

echo 'PASS queue_dev_workflow_contract_static'
