#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
grep -q 'elif key == "security_reason"' queuemgr_panel.py
grep -q 'elif key == "authorisation"' queuemgr_panel.py
grep -q 'elif key == "no_security_exemption"' queuemgr_panel.py
python3 -m py_compile queuemgr_panel.py
echo '[PASS] Task Creator F10 edits security exemption fields'
