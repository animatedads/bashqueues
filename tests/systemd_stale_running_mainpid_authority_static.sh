#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "[FAIL] $*" >&2; exit 1; }
grep -q '_queue_systemd_unit_authoritative_running' queuebash.sh || fail "authoritative systemd stale helper missing"
grep -q '_queue_systemd_unit_status_for_stale_check' queuebash.sh || fail "systemd stale status helper missing"
grep -q 'RUN_PID is only the systemd-run launcher/client' queuebash.sh || fail "RUN_PID fallback boundary comment missing"
grep -q 'systemd_stale_running_mainpid_authority_smoke' tests/systemd_stale_running_mainpid_authority_smoke.sh || true
echo "[PASS] systemd stale-running MainPID authority guard is wired"
