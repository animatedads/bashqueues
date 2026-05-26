#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

[[ -x bin/bashqueues-cron-class-selector.py ]] || fail "selector missing or not executable"
python3 -m py_compile bin/bashqueues-cron-ticker.py bin/bashqueues-cron-class-selector.py

grep -q '_cron_selector_path' bin/bashqueues-cron-ticker.py || fail "ticker selector path helper missing"
grep -q '_cron_select_class' bin/bashqueues-cron-ticker.py || fail "ticker selector invocation helper missing"
grep -q 'QUEUEBASH_CRON_CLASS_SELECTOR_MIN_CONFIDENCE' bin/bashqueues-cron-ticker.py || fail "selector min confidence env missing"
grep -q 'selector chose class' bin/bashqueues-cron-ticker.py || fail "below-minimum selector warning missing"

echo "[PASS] cron class selector is wired into ticker"
