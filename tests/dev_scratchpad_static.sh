#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "FAIL: $*" >&2; exit 1; }

[[ -f queuebash.sh ]] || fail "run from repository root"
grep -Eq 'QUEUEBASH_VERSION="0\.18\.(4[0-9]|[5-9][0-9])"' queuebash.sh || fail 'queuebash version must be 0.18.28 or newer'
grep -Eq 'WIZARD_VERSION="0\.18\.(27|28|29|30)"' bin/queue-policy-wizard || fail 'wizard version missing expected 0.18.x line'
grep -q '^## 0.18.24 internal dev scratchpad import contract' README.md || fail 'README missing scratchpad release section'
grep -q '^## 0.18.24 - internal dev scratchpad import contract' CHANGELOG.md || fail 'CHANGELOG missing scratchpad release section'
[[ -f docs/DEV_SCRATCHPAD.md ]] || fail 'missing scratchpad doc'
[[ -f tests/dev_scratchpad_smoke.sh ]] || fail 'missing scratchpad smoke test'
[[ -f tests/dev_scratchpad_json_contract_static.py ]] || fail 'missing scratchpad JSON contract test'

grep -q '_queue_dev_scratchpad_path()' queuebash.sh || fail 'missing scratchpad path helper'
grep -q 'QUEUEBASH_DEV_SCRATCHPAD' queuebash.sh || fail 'path override missing'
grep -q '_queue_dev_scratchpad_command()' queuebash.sh || fail 'missing _queue_dev_scratchpad_command'
grep -q 'scratchpad) _queue_dev_scratchpad_command' queuebash.sh || fail 'dev dispatcher missing scratchpad subcommand'
grep -q 'queue dev scratchpad' queuebash.sh || fail 'dev usage missing scratchpad'
grep -q 'queue dev scratchpad list' queuebash.sh || fail 'dev usage missing scratchpad list'
grep -q 'queue dev scratchpad delete' queuebash.sh || fail 'dev usage missing scratchpad delete'
grep -q 'def command_list' queuebash.sh || fail 'missing scratchpad list implementation'
grep -q 'def command_delete' queuebash.sh || fail 'missing scratchpad delete implementation'

grep -q 'queuebash.dev_scratchpad.v1' queuebash.sh || fail 'scratchpad ledger schema missing'
grep -q 'queuebash.dev_scratchpad_item.v1' queuebash.sh || fail 'scratchpad item schema missing'
grep -q 'queuebash.dev_scratchpad_working_set.v1' queuebash.sh || fail 'scratchpad working set schema missing'

grep -q 'architect' docs/DEV_SCRATCHPAD.md || fail 'authority types not documented'
grep -q 'source_tree' docs/DEV_SCRATCHPAD.md || fail 'source_tree authority not documented'
grep -q 'next --json' docs/DEV_SCRATCHPAD.md || fail 'next JSON view not documented'
grep -q 'export --json' docs/DEV_SCRATCHPAD.md || fail 'export JSON view not documented'
grep -q 'no prompt renderer' docs/DEV_SCRATCHPAD.md || fail 'prompt renderer exclusion not documented'
grep -q 'no `queue dev test` integration' docs/DEV_SCRATCHPAD.md || fail 'queue dev test integration exclusion not documented'
grep -q 'authority="source_tree"' queuebash.sh || fail 'import must use source_tree authority'
grep -q 'confidence="observed"' queuebash.sh || fail 'import must use observed confidence'
grep -q 'os.replace(tmp, path)' queuebash.sh || fail 'atomic write pattern missing'

scratch_body="$(awk '/^_queue_dev_test_usage\(\)/{exit} seen{print} /^_queue_dev_scratchpad_path\(\)/{seen=1; print}' queuebash.sh)"
if printf '%s\n' "$scratch_body" | grep -Eq '_queue_dev_test|queue dev test --scratchpad|generateContent|ollama|openai|gemini'; then
  fail 'scratchpad implementation must not integrate test runner or AI providers'
fi
if printf '%s\n' "$scratch_body" | grep -Eq '^queue\(\)|_queue_resolve_job_operand'; then
  fail 'scratchpad release must not refactor queue or job resolution'
fi

[[ ! -e assets.d/net_usage.sh ]] || fail 'assets.d/net_usage.sh must remain absent'
[[ -e caps.d/net_usage.sh ]] || fail 'caps.d/net_usage.sh should remain present'

echo 'PASS dev_scratchpad_static'
