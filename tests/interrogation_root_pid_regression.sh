#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"
export QUEUEBASH_INTERROGATE_PRE_ARM_DELAY=0.05
export QUEUEBASH_INTERROGATE_SAMPLE_INTERVAL=0.05
mkdir -p "$QUEUEBASH_ROOT"
set +e
"$ROOT/bin/queue-interrogate" repeat root-pid-regression --count 2 -- bash -c 'echo ok; sleep 0.1' >"$tmp/out" 2>"$tmp/err"
rc=$?
set -e
cat "$tmp/out"
if grep -q 'root_pid: unbound variable' "$tmp/err"; then
  echo '[FAIL] queue-interrogate emitted root_pid unbound variable' >&2
  cat "$tmp/err" >&2
  exit 1
fi
[[ "$rc" -eq 0 ]] || { echo "[FAIL] queue-interrogate exited $rc" >&2; cat "$tmp/err" >&2; exit 1; }
grep -q 'interrogation_campaign=' "$tmp/out"
echo '[PASS] interrogation root_pid regression checks pass'
