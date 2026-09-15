#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail(){ echo "FAIL: $*" >&2; exit 1; }

[[ -f queuebash.sh ]] || fail 'run from repository root'
grep -Eq 'QUEUEBASH_VERSION="0\.18\.(4[3-9]|[5-9][0-9])"' queuebash.sh || fail 'queuebash version must preserve 0.18.43+ queue dev contract line'
grep -Eq '^#{1,2} 0.18.43 BOB12 dev workflow command contracts' README.md || fail 'README missing 0.18.43 workflow contract entry'
grep -Eq '^#{1,2} 0.18.42 BOB12 queue dev contract cleanup merged' README.md || fail 'README 0.18.42 queue dev contract entry missing'
grep -q '^## 0.18.43 - BOB12 dev workflow command contracts' CHANGELOG.md || fail 'CHANGELOG missing 0.18.43 workflow contract entry'
grep -q '^## 0.18.42 - BOB12 queue dev contract cleanup merged' CHANGELOG.md || fail 'CHANGELOG 0.18.42 queue dev contract entry missing'

[[ -f docs/QUEUE_DEV_CONTRACT.md ]] || fail 'missing queue dev contract doc'
[[ -f docs/QUEUE_DEV_SECURITY_MODEL.md ]] || fail 'missing queue dev security model doc'
[[ -f docs/QUEUE_DEV_REMOTE_REVIEW_WORKFLOW.md ]] || fail 'missing queue dev remote review workflow doc'
[[ -f tests/queue_dev_json_contract_static.py ]] || fail 'missing queue dev json contract test'
[[ -f tests/queue_dev_docs_consistency_static.sh ]] || fail 'missing queue dev docs consistency test'

for cmd in functions locate extract scope patch splice test comment diff strip symbols flow scratchpad; do
  grep -q "queue dev ${cmd}" docs/QUEUE_DEV_CONTRACT.md || fail "contract doc missing queue dev ${cmd}"
done

grep -q 'rollback' docs/QUEUE_DEV_CONTRACT.md || fail 'contract doc missing rollback alias'
grep -q 'dev.functions' docs/QUEUE_DEV_REMOTE_REVIEW_WORKFLOW.md || fail 'remote workflow missing named operation examples'
grep -q 'must not grow `exec`, `shell`, `bash`, `cmd`' docs/QUEUE_DEV_SECURITY_MODEL.md || fail 'security model missing no-shell boundary'
grep -q 'queue dev test remains bounded execution evidence\|Test execution may produce evidence' docs/QUEUE_DEV_SECURITY_MODEL.md docs/QUEUE_DEV_CONTRACT.md || fail 'scratchpad/test separation not documented'

# Implementation still exposes the controlled command surface.
grep -q '_queue_dev_command()' queuebash.sh || fail 'missing queue dev dispatcher'
grep -q 'functions|list) _queue_dev_functions' queuebash.sh || fail 'functions dispatcher missing'
grep -q 'locate) _queue_dev_locate' queuebash.sh || fail 'locate dispatcher missing'
grep -q 'extract) _queue_dev_extract' queuebash.sh || fail 'extract dispatcher missing'
grep -q 'scope) _queue_dev_scope' queuebash.sh || fail 'scope dispatcher missing'
grep -q 'patch) _queue_dev_patch' queuebash.sh || fail 'patch dispatcher missing'
grep -q 'splice) _queue_dev_splice' queuebash.sh || fail 'splice dispatcher missing'
grep -q 'test) _queue_dev_test_command' queuebash.sh || fail 'test dispatcher missing'
grep -q 'comment) _queue_dev_comment' queuebash.sh || fail 'comment dispatcher missing'
grep -q 'diff) _queue_dev_diff' queuebash.sh || fail 'diff dispatcher missing'
grep -q 'strip|rollback) _queue_dev_strip' queuebash.sh || fail 'strip/rollback dispatcher missing'
grep -q 'symbols) _queue_dev_symbols' queuebash.sh || fail 'symbols dispatcher missing'
grep -q 'flow|graph|paths) _queue_dev_flow' queuebash.sh || fail 'flow dispatcher missing'
grep -q 'scratchpad) _queue_dev_scratchpad_command' queuebash.sh || fail 'scratchpad dispatcher missing'

! [[ -e assets.d/net_usage.sh ]] || fail 'assets.d/net_usage.sh must remain absent'
[[ -e caps.d/net_usage.sh ]] || fail 'caps.d/net_usage.sh should remain present'

echo 'PASS queue_dev_contract_static'
