#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "[FAIL] $*" >&2; exit 1; }
pass() { echo "[PASS] $*"; }

grep -Eq 'QUEUEBASH_VERSION="0\.[0-9]+\.[0-9]+"' queuebash.sh || fail "queuebash version string missing/malformed"
grep -q '_queue_install_bundled_cap_plugins' queuebash.sh || fail "bundled caps.d installer missing"
grep -q 'caps.d/.disabled' queuebash.sh || fail "caps disable directory missing"
grep -q 'queue module list' queuebash.sh || fail "queue module list usage missing"
grep -q 'queue module explain' queuebash.sh || fail "queue module explain usage missing"
grep -q '_queue_module_disable' queuebash.sh || fail "module disable helper missing"
grep -q '_queue_module_enable' queuebash.sh || fail "module enable helper missing"
grep -q 'queue caps list' queuebash.sh || fail "caps list usage missing"
grep -q 'queue caps .*enable <family>' queuebash.sh || grep -q 'queue caps list|explain <family>|refresh <directory>|enable <family>|disable <family>' queuebash.sh || fail "caps management dispatcher not documented in usage"
grep -q 'ViewState("modules", "Modules", load_modules, detail_module)' queuemgr_panel.py || fail "panel Modules view missing"
grep -q 'curses.KEY_BTAB, 353' queuemgr_panel.py || fail "Shift-Tab reverse navigation missing"
grep -q 'module asset net disable' docs/QUEUEMGR.md || grep -q 'modules disable asset net' docs/QUEUEMGR.md || fail "QueueManager docs do not document module command examples"
grep -q 'queue module enable cap billing' README.md || grep -q 'queue modules enable cap billing' README.md || fail "README does not document caps module enable/disable"
pass "modules/caps/class enable-disable management and Shift-Tab support are present"

# Functional smoke test in an isolated queue root.
# Keep this test intentionally narrow: earlier suite runs can leave cap/plugin
# state around, and a full queue list bootstrap is much heavier than this
# module enable/disable contract needs.
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
root="$(mktemp -d)/queue"
rm -rf "$root"
mkdir -p "$root/caps.d" "$root/empty-source/classes" "$root/empty-source/envs.d" "$root/empty-source/assets.d" "$root/empty-source/caps.d" "$root/empty-source/reporters.d" "$root/empty-source/policies.d"
cp caps.d/billing.sh "$root/caps.d/billing.sh"
export QUEUEBASH_ROOT="$root"
export QUEUEBASH_CLASS_SOURCE_DIR="$root/empty-source/classes"
export QUEUEBASH_ENV_SOURCE_DIR="$root/empty-source/envs.d"
export QUEUEBASH_PLUGIN_SOURCE_DIR="$root/empty-source/assets.d"
export QUEUEBASH_CAP_PLUGIN_SOURCE_DIR="$root/empty-source/caps.d"
export QUEUEBASH_REPORTER_PLUGIN_SOURCE_DIR="$root/empty-source/reporters.d"
export QUEUEBASH_POLICY_SOURCE_DIR="$root/empty-source/policies.d"
source ./queuebash.sh >/dev/null
QUEUEBASH_ROOT="$root" queue module list | grep -q $'cap	billing	enabled' || fail "billing cap was not installed/listed as enabled"
QUEUEBASH_ROOT="$root" queue module disable cap billing >/dev/null
QUEUEBASH_ROOT="$root" queue module list | grep -q $'cap	billing	disabled' || fail "billing cap was not disabled"
QUEUEBASH_ROOT="$root" queue caps list | grep -qv '^billing:' || true
QUEUEBASH_ROOT="$root" queue module enable cap billing >/dev/null
QUEUEBASH_ROOT="$root" queue module list | grep -q $'cap	billing	enabled' || fail "billing cap was not re-enabled"
pass "functional cap module enable/disable smoke test passed"

exit 0
