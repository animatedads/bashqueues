#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail(){ echo "FAIL: $*" >&2; exit 1; }

[[ -f queuebash.sh ]] || fail 'run from repository root'
grep -Eq 'QUEUEBASH_VERSION="0\.18\.(44|45|46|47|([5-9][0-9]|[1-9][0-9][0-9]))"' queuebash.sh || fail 'version must be 0.18.44 or later'
grep -q '^# 0.18.44 BOB12 scratchpad lifecycle commands' README.md || fail 'README missing historical 0.18.44 entry'
grep -q '^## 0.18.44 - BOB12 scratchpad lifecycle commands' CHANGELOG.md || fail 'CHANGELOG missing historical 0.18.44 entry'
[[ -f docs/QUEUE_DEV_SCRATCHPAD_LIFECYCLE.md ]] || fail 'missing lifecycle doc'
[[ -f tests/dev_scratchpad_lifecycle_smoke.sh ]] || fail 'missing lifecycle smoke test'
[[ -f tests/dev_scratchpad_lifecycle_json_contract_static.py ]] || fail 'missing lifecycle JSON contract test'

grep -q 'queue dev scratchpad status set' queuebash.sh || fail 'usage missing status set'
grep -q 'queue dev scratchpad supersede' queuebash.sh || fail 'usage missing supersede'
grep -q 'def command_lifecycle_status' queuebash.sh || fail 'missing lifecycle status implementation'
grep -q 'def command_supersede' queuebash.sh || fail 'missing supersede implementation'
grep -q 'queuebash.dev_workflow.scratchpad_status.v1' queuebash.sh || fail 'missing status response schema'
grep -q 'queuebash.dev_workflow.supersede.v1' queuebash.sh || fail 'missing supersede response schema'
grep -q 'superseded_by' queuebash.sh || fail 'missing superseded_by relation'
grep -q 'require_high_authority' queuebash.sh || fail 'missing high authority gate'

grep -q 'queue dev scratchpad status set' docs/QUEUE_DEV_SCRATCHPAD_LIFECYCLE.md || fail 'doc missing status set command'
grep -q 'queue dev scratchpad supersede' docs/QUEUE_DEV_SCRATCHPAD_LIFECYCLE.md || fail 'doc missing supersede command'
grep -q 'export --json' docs/QUEUE_DEV_SCRATCHPAD_LIFECYCLE.md || fail 'doc missing full export boundary'
grep -q 'does not refactor queue dispatch' docs/QUEUE_DEV_SCRATCHPAD_LIFECYCLE.md || fail 'doc missing dispatcher boundary'

body="$(awk '/^_queue_dev_test_usage\(\)/{exit} seen{print} /^_queue_dev_scratchpad_path\(\)/{seen=1; print}' queuebash.sh)"
if printf '%s\n' "$body" | grep -Eq 'generateContent|ollama|openai|gemini|queue dev test --scratchpad'; then
  fail 'lifecycle implementation must not hook AI providers or queue dev test'
fi
[[ ! -e assets.d/net_usage.sh ]] || fail 'assets.d/net_usage.sh must remain absent'
[[ -e caps.d/net_usage.sh ]] || fail 'caps.d/net_usage.sh should remain present'

echo 'PASS dev_scratchpad_lifecycle_static'
