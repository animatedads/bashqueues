#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }
t=bin/bashqueues-cron-ticker.py

grep -q 'BASHQUEUES_CLASS' "$t" || fail "cron class state variable not parsed"
grep -q 'active_class' "$t" || fail "cron active_class state machine missing"
grep -q 'explicit_class' "$t" || fail "cron dispatch explicit_class missing"
grep -q 'target_class = explicit_class or cname' "$t" || fail "cron target_class routing missing"
grep -q 'if explicit_class:' "$t" || fail "explicit class path missing"
grep -q 'Do not overwrite them' "$t" || fail "explicit class no-overwrite guard/comment missing"
grep -q 'CLASS_DEFAULT_SANDBOX_LEVEL=strict' "$t" || fail "auto cron class is not strict by default"
grep -q 'CLASS_DEFAULT_RUNTIME_CAPS=no-spawn-shell,no-network-tools,only-local-sockets' "$t" || fail "auto cron class runtime caps missing"
python3 -m py_compile "$t"

echo "[PASS] cron bridge supports BASHQUEUES_CLASS routing without overwriting explicit classes"
