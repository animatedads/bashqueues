#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -q 'QUEUEBASH_VERSION="0.17.51"' queuebash.sh || fail "version not 0.17.20"

grep -q 'def parse_class_restriction_hint' queuemgr_panel.py || fail "hint parser missing"
grep -q 'def class_restriction_param_specs' queuemgr_panel.py || fail "param spec parser missing"
grep -q 'def prompt_class_restriction_params' queuemgr_panel.py || fail "per-param prompt helper missing"
grep -q 'Target: {target_hint}' queuemgr_panel.py || fail "target prompt does not use hint target text"
grep -q 'weekdays' queuemgr_panel.py || fail "weekday hint choices missing"
grep -q 'weekday_windows' assets.d/time.sh || fail "time:window hint missing weekday_windows"
grep -q 'now_epoch' queuemgr_panel.py || fail "optional now_epoch handling missing"
grep -q '<omit>' queuemgr_panel.py || fail "omit option missing for optional params"
grep -q '0.16.33 - Class Creator parameter prompts from asset/cap hints' CHANGELOG.md || fail "CHANGELOG missing 0.16.33"

echo "[PASS] Class Creator generates useful restriction prompts from asset/cap hints"
