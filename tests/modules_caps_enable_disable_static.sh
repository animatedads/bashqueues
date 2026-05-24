#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "[FAIL] $*" >&2; exit 1; }
pass() { echo "[PASS] $*"; }

grep -q 'QUEUEBASH_VERSION="0.16.25"' queuebash.sh || fail "version not bumped to 0.16.25"
grep -q '_queue_install_bundled_cap_plugins' queuebash.sh || fail "bundled caps.d installer missing"
grep -q 'caps.d/.disabled' queuebash.sh || fail "caps disable directory missing"
grep -q 'queue modules list|explain' queuebash.sh || fail "queue modules dispatcher usage missing"
grep -q '_queue_module_disable' queuebash.sh || fail "module disable helper missing"
grep -q '_queue_module_enable' queuebash.sh || fail "module enable helper missing"
grep -q 'queue caps list|explain <family>|refresh <directory>|enable <family>|disable <family>' queuebash.sh || fail "caps management dispatcher not documented in usage"
grep -q 'ViewState("modules", "Modules", load_modules, detail_module)' queuemgr_panel.py || fail "panel Modules view missing"
grep -q 'curses.KEY_BTAB, 353' queuemgr_panel.py || fail "Shift-Tab reverse navigation missing"
grep -q 'module asset net disable' docs/QUEUEMGR.md || fail "QueueManager docs do not document module command examples"
grep -q 'queue modules enable cap billing' README.md || fail "README does not document caps module enable/disable"
pass "modules/caps/class enable-disable management and Shift-Tab support are present"

# Functional smoke test in an isolated queue root.
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh >/dev/null
root="$(mktemp -d)/queue"
QUEUEBASH_ROOT="$root" \
QUEUEBASH_CLASS_SOURCE_DIR="$PWD/classes" \
QUEUEBASH_PLUGIN_SOURCE_DIR="$PWD/assets.d" \
QUEUEBASH_CAP_PLUGIN_SOURCE_DIR="$PWD/caps.d" \
queue list >/dev/null
QUEUEBASH_ROOT="$root" queue modules list | grep -q $'cap\tbilling\tenabled' || fail "billing cap was not installed/listed as enabled"
QUEUEBASH_ROOT="$root" queue modules disable cap billing >/dev/null
QUEUEBASH_ROOT="$root" queue modules list | grep -q $'cap\tbilling\tdisabled' || fail "billing cap was not disabled"
QUEUEBASH_ROOT="$root" queue caps list | grep -qv '^billing:' || true
QUEUEBASH_ROOT="$root" queue modules enable cap billing >/dev/null
QUEUEBASH_ROOT="$root" queue modules list | grep -q $'cap\tbilling\tenabled' || fail "billing cap was not re-enabled"
pass "functional cap module enable/disable smoke test passed"
