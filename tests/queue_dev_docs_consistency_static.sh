#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail(){ echo "FAIL: $*" >&2; exit 1; }

[[ -f queuebash.sh ]] || fail 'run from repository root'
[[ -f docs/QUEUE_DEV_CONTRACT.md ]] || fail 'missing docs/QUEUE_DEV_CONTRACT.md'

help_block="$(sed -n '/^_queue_dev_usage()/,/^}/p' queuebash.sh)"
contract="$(cat docs/QUEUE_DEV_CONTRACT.md)"

required_help_fragments=(
  'queue dev functions [--file FILE] [--json] [prefix]'
  'queue dev locate FUNCTION [--json]'
  'queue dev extract FUNCTION [--file FILE] [--json]'
  'queue dev scope [--json] [--prefix PREFIX]'
  'queue dev patch --file FILE --function FUNCTION --source SOURCE [--json] [--no-syntax-check]'
  'queue dev splice --file FILE'
  'queue dev test [--run] [--name NAME] [--timeout SEC] [--json] -- COMMAND...'
  'queue dev test result JOBID [--root DIR] [--json]'
  'queue dev comment --file FILE --function FUNCTION --message TEXT [--changelog] [--json]'
  'queue dev diff --file FILE [--function FUNCTION] [--json]'
  'queue dev strip --file FILE --function FUNCTION [--json]'
  'queue dev symbols --file FILE [--function FUNCTION] [--json]'
  'queue dev flow --file FILE [--function FUNCTION] [--json]'
  'queue dev scratchpad help|init|import|add|task|attempt|evidence|done|reject|fail|bump-fail|list|delete|next|export|explain'
)

for frag in "${required_help_fragments[@]}"; do
  grep -Fq "$frag" <<<"$help_block" || fail "help missing: $frag"
  grep -Fq "$frag" <<<"$contract" || fail "contract missing: $frag"
done

for implementation_function in \
  _queue_dev_functions \
  _queue_dev_locate \
  _queue_dev_extract \
  _queue_dev_scope \
  _queue_dev_patch \
  _queue_dev_splice \
  _queue_dev_test_command \
  _queue_dev_comment \
  _queue_dev_diff \
  _queue_dev_strip \
  _queue_dev_symbols \
  _queue_dev_flow \
  _queue_dev_scratchpad_command; do
  grep -q "^${implementation_function}()" queuebash.sh || fail "missing ${implementation_function}"
done

echo 'PASS queue_dev_docs_consistency_static'
