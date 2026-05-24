#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
from pathlib import Path
src = Path('queuemgr_panel.py').read_text()
assert 'def execute_asset_command' in src, 'missing typed asset command dispatcher'
assert 'def perform_asset_command_action' in src, 'missing typed asset action performer'
assert 'asset_context_heads = ["select", "explain", "hint", "show", "validate", "enable", "disable", "delete", "refresh", "rollback"]' in src, 'assets panel bare command context missing'
assert 'class_context_heads = ["select", "explain", "show", "validate", "enable", "disable", "edit", "delete", "refresh", "rollback", "history", "backups", "use"]' in src, 'classes panel bare command context missing'
assert 'self.execute_asset_command(tail)' in src, 'explicit asset command routing missing'
assert 'add(f"asset {cur.key} {action}")' in src, 'asset contextual star completions missing'
assert 'qrun(["assets", "disable", family]' in src, 'asset disable command path missing'
assert 'qrun(["classes", "disable", class_name]' in src, 'class disable command path missing'
assert 'assets.d/net_usage.sh' not in '\n'.join(str(p) for p in Path('.').rglob('*')), 'assets.d/net_usage.sh must remain absent'
print('[PASS] Asset and class actions are available from the F2 command line')
PY
