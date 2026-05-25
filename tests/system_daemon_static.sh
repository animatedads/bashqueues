#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "[FAIL] $*" >&2; exit 1; }
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
grep -q '_queue_system_daemon_command' queuebash.sh || fail "missing system daemon command function"
grep -q 'system-daemon' queuebash.sh || fail "missing system-daemon command dispatch"
grep -q 'runuser -u "$user"' queuebash.sh || fail "system daemon does not delegate with runuser"
grep -q 'queue daemon --once --min-workers' queuebash.sh || fail "system daemon does not call per-user daemon"
[[ -f systemd/bashqueues-daemon.service ]] || fail "missing system daemon service"
grep -q 'queue system-daemon --interval 30 --min-workers 1' systemd/bashqueues-daemon.service || fail "service does not run system daemon"
grep -q -- '--with-daemon' install-system.sh || fail "installer missing --with-daemon"
echo "[PASS] system multi-user daemon is wired"
