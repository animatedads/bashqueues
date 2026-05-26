#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

grep -q 'queue dev symbols' queuebash.sh
grep -q '_queue_dev_symbols()' queuebash.sh
grep -q 'symbols) _queue_dev_symbols' queuebash.sh
grep -q 'def _dev_symbols' queuemgr_panel.py
grep -q 'cmd == "symbols"' queuemgr_panel.py

echo '[PASS] queue dev symbols static wiring present'
