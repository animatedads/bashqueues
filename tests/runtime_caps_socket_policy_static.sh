#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "[FAIL] $*" >&2; exit 1; }
pass() { echo "[PASS] $*"; }

grep -q 'QUEUEBASH_VERSION="0.17.25"' queuebash.sh || fail "version not bumped"

grep -q 'runtime:only_local_sockets' caps.d/runtime.sh || fail "runtime:only_local_sockets facility missing"
grep -q 'runtime:only_port' caps.d/runtime.sh || fail "runtime:only_port facility missing"
grep -q 'queue_cap_candidate_runtime_only_local_sockets' caps.d/runtime.sh || fail "only-local candidate missing"
grep -q 'queue_cap_candidate_runtime_only_port' caps.d/runtime.sh || fail "only-port candidate missing"

grep -q 'CLASS_DEFAULT_RUNTIME_CAP_PORTS' queuebash.sh || fail "runtime cap ports class default missing"
grep -q '_queue_runtime_caps_lsof_local_only_violation' queuebash.sh || fail "local-only lsof policy missing"
grep -q '_queue_runtime_caps_lsof_port_violation' queuebash.sh || fail "port lsof policy missing"
grep -q '_queue_runtime_caps_socket_policy_port' queuebash.sh || fail "socket port extraction missing"
grep -q 'only-local-sockets' queuebash.sh || fail "watchdog does not check only-local-sockets"
grep -q 'only-port' queuebash.sh || fail "watchdog does not check only-port"

grep -q 'CLASS_DEFAULT_RUNTIME_CAP_PORTS' docs/CAPS.md || fail "CAPS docs missing runtime port allow-list"
grep -q 'only-local-sockets' docs/CAPS.md || fail "CAPS docs missing only-local-sockets"
grep -q 'only-port' docs/CAPS.md || fail "CAPS docs missing only-port"

pass "runtime caps support localhost-only and port allow-list socket policies"
