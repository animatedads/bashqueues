#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail(){ echo "[FAIL] $*" >&2; exit 1; }
pass(){ echo "[PASS] $*"; }

grep -q 'QUEUEBASH_VERSION="0.17.25"' queuebash.sh || fail "version not bumped"
[[ -f caps.d/runtime.sh ]] || fail "caps.d/runtime.sh missing"
! [[ -f assets.d/net_usage.sh ]] || fail "assets.d/net_usage.sh must remain removed"

grep -q 'runtime:no_spawn_shell' caps.d/runtime.sh || fail "runtime no_spawn_shell facility missing"
grep -q 'runtime:no_network_tools' caps.d/runtime.sh || fail "runtime no_network_tools facility missing"
grep -q 'runtime:no_network_sockets' caps.d/runtime.sh || fail "runtime no_network_sockets facility missing"

grep -q 'CLASS_DEFAULT_RUNTIME_CAPS' queuebash.sh || fail "class runtime cap defaults not loaded"
grep -q '_queue_runtime_caps_watchdog' queuebash.sh || fail "runtime caps watchdog missing"
grep -q 'lsof -nP -a -p' queuebash.sh || fail "lsof -p socket inspection missing"
grep -q 'no-spawn-shell' queuebash.sh || fail "no-spawn-shell enforcement missing"
grep -q 'no-network-tools' queuebash.sh || fail "no-network-tools enforcement missing"
grep -q 'RUNTIME_CAP_VIOLATED' queuebash.sh || fail "runtime cap metadata missing"
grep -q 'runtime_cap_violation' queuebash.sh || fail "runtime cap audit event missing"

pass "runtime caps plugin and worker watchdog are wired"
