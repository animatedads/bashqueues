#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

grep -q '_queue_dev_comment()' queuebash.sh
grep -q '_queue_dev_diff()' queuebash.sh
grep -q '_queue_dev_strip()' queuebash.sh
grep -q 'comment) _queue_dev_comment' queuebash.sh
grep -q 'diff) _queue_dev_diff' queuebash.sh
grep -q 'strip|rollback) _queue_dev_strip' queuebash.sh
grep -q 'Europe/London' queuebash.sh
grep -q '\[AI-PATCH' queuebash.sh

grep -q '_dev_patch' queuemgr_panel.py
grep -q '_dev_locate_and_extract' queuemgr_panel.py
grep -q 'sys.argv\[1\] == "--dev"' queuemgr_panel.py

echo '[PASS] queue dev comment/diff/strip and Python --dev hooks are present'
