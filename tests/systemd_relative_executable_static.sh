#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -Eq 'QUEUEBASH_VERSION="0\.[0-9]+\.[0-9]+"' queuebash.sh || fail "queuebash version string missing/malformed"
grep -q '_queue_absolutize_systemd_argv0' queuebash.sh || fail "missing systemd argv0 normaliser"
grep -Fq '_queue_emit_systemd_payload_argv "$cwd" "$timeout_value" "$kill_after" "$@"' queuebash.sh || fail "systemd payload path does not use normaliser"
grep -q 'systemd-run accepts either a simple executable name' queuebash.sh || fail "missing rationale comment"

echo '[PASS] systemd runner normalises relative executable argv0 values'
