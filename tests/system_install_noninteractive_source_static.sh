#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -x install-system.sh ]]
bash -n install-system.sh
grep -q 'export QUEUEBASH_ALLOW_NONINTERACTIVE=1' install-system.sh
grep -q 'source "$src_dir/queuebash.sh"' install-system.sh
grep -q 'source "$share_dir/queuebash.sh"' install-system.sh
python3 - <<'PY'
from pathlib import Path
s = Path('install-system.sh').read_text()
wrapper = s.split('cat > "$bin_dir/queue" <<EOFWRAP', 1)[1].split('EOFWRAP', 1)[0]
dogfood = s.split('export QUEUEBASH_ROOT="$install_queue"', 1)[1].split('queue submit system-install-core', 1)[0]
assert 'QUEUEBASH_ALLOW_NONINTERACTIVE=1' in wrapper
assert 'QUEUEBASH_ALLOW_NONINTERACTIVE=1' in dogfood
assert 'source "$share_dir/queuebash.sh"' in wrapper
assert 'source "$src_dir/queuebash.sh"' in dogfood
PY
echo "[PASS] system installer and generated queue wrapper source queuebash non-interactively"
