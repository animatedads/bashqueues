#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

bash -n install-system.sh

python3 - <<'PY'
from pathlib import Path
s = Path('install-system.sh').read_text()
required = [
    'for dir in assets.d caps.d reporters.d classes envs.d policies.d docs bin systemd tests resources.d; do',
    'Installed display/resource files under $share_dir/resources.d',
    'code/plugin/resource signing of installed tree failed',
    'code/plugin/resource signature verification reported issues',
]
for needle in required:
    if needle not in s:
        raise SystemExit(f'missing installer resource/signing contract text: {needle}')
if 'queue code sign --tree "$share_dir"' not in s or 'queue code verify --tree "$share_dir"' not in s:
    raise SystemExit('installer does not sign and verify the installed share tree')
q = Path('queuebash.sh').read_text()
for needle in [
    'printf \'%s\\n\' "$script_dir/resources.d"',
    '-path "$tree/resources.d/display/*"',
    '-path "$tree/resources.d/display/*/*"',
    '-path "$tree/resources.d/xml/*"',
    '-path "$tree/resources.d/xml/*/*"',
]:
    if needle not in q:
        raise SystemExit(f'queuebash resource/signature contract missing: {needle}')
PY

echo "[PASS] system installer installs resources.d and signs/verifies installed display resources"
