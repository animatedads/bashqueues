#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }
q=queuebash.sh

grep -q 'QUEUEBASH_VERSION="0.17.25"' "$q" || fail "version not 0.17.20"
grep -q 'CLASS_DEFAULT_SECCOMP_PROFILE' "$q" || fail "class seccomp default not loaded"
grep -q 'CLASS_DEFAULT_SECCOMP_ALLOW' "$q" || fail "class seccomp allow default not loaded"
grep -q 'SystemCallArchitectures=native' policies.d/seccomp/docker-default.env || fail "systemd seccomp architecture policy missing"
grep -q 'SystemCallFilter=~@clock @debug @module @mount @obsolete @privileged @raw-io @reboot @swap @cpu-emulation @keyring' policies.d/seccomp/docker-default.env || fail "docker-default seccomp filter missing"
grep -q 'SystemCallFilter=@system-service' policies.d/seccomp/strict.env || fail "strict seccomp profile missing"
grep -q -- '--sandbox-override' "$q" || fail "sandbox override submit flag missing"
grep -q -- '--seccomp-allow' "$q" || fail "seccomp allow submit flag missing"
grep -q -- '--drop-cap' "$q" || fail "drop-cap submit flag missing"
grep -q -- '--add-port' "$q" || fail "add-port submit flag missing"
grep -q 'EXCEPTION_SANDBOX_OVERRIDE' "$q" || fail "sandbox exception not written/explained"
grep -q 'EXCEPTION_SECCOMP_ALLOW' "$q" || fail "seccomp exception not written/explained"
grep -q 'EXCEPTION_DROP_CAP' "$q" || fail "drop-cap exception not written/explained"
grep -q 'EXCEPTION_ADD_PORT' "$q" || fail "add-port exception not written/explained"
grep -q '_queue_apply_security_exception_overlays_for_current_job' "$q" || fail "exception overlay reconciliation missing"
grep -q 'HOLE PUNCHED' "$q" || fail "visible seccomp exception wording missing"

echo "[PASS] seccomp profiles and sandbox/cap exception overlays are wired"
