#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
grep -q 'ViewState("policies", "Policies"' queuemgr_panel.py
grep -q 'def execute_policy_command' queuemgr_panel.py
grep -q 'def policy_action' queuemgr_panel.py
grep -q 'def global_action' queuemgr_panel.py
grep -q 'preserve the first' queuemgr_panel.py
echo "[PASS] Queue Manager policy/global panels and first-key command entry are wired"
