#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
fail(){ echo "FAIL installer_tree_coverage_static: $*" >&2; exit 1; }
loop_line='for dir in assets.d caps.d reporters.d classes envs.d policies.d docs bin systemd tests resources.d providers.d schemas fixtures contracts; do'
grep -qF "$loop_line" install-system.sh || fail 'installer shared-tree loop missing required directories'
for dir in providers.d policies.d tests resources.d schemas docs assets.d bin classes fixtures contracts; do
  [[ -d "$dir" ]] || fail "source tree missing expected directory $dir"
  grep -q "$dir" install-system.sh || fail "installer does not mention $dir"
done
grep -q 'remote-admin provider helper' install-system.sh || fail 'remote-admin post-install helper assertion missing'
bash -n install-system.sh

echo 'PASS installer_tree_coverage_static'
