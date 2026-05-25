#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
grep -q 'CLASS_POLICY_BLOCK_COMMAND_HASHES' policies.d/class-statement/default.env
grep -q 'CLASS_POLICY_BLOCK_COMMAND_WORDS' policies.d/class-statement/default.env
grep -q 'CLASS_POLICY_BLOCK_COMMAND_PATTERNS' policies.d/class-statement/default.env
grep -q '_queue_policy_command_word_in_list' queuebash.sh
grep -q '_queue_policy_command_pattern_matches' queuebash.sh
grep -q 'ALLOW_BLOCKED_COMMAND_HASHES' queuebash.sh
grep -q 'docs/POLICY_COMMAND_BLOCKS.md' README.md
echo '[PASS] policy command block hooks are present'
