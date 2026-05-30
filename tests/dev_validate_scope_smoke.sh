#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

runner="bin/queue-dev-timeout"
[[ -x "$runner" ]] || runner="timeout"
run_bounded() {
  if [[ "$runner" == "timeout" ]]; then timeout 30 "$@"; else "$runner" --timeout 30 -- "$@"; fi
}

run_bounded bash -lc 'source ./queuebash.sh >/dev/null 2>&1; queue dev validate --quick --timeout 20 --json' > /tmp/queue-dev-validate-smoke.json
grep -q '"schema":"queuebash.dev_validate_result.v1"' /tmp/queue-dev-validate-smoke.json
grep -q '"status":"pass"' /tmp/queue-dev-validate-smoke.json

run_bounded bash -lc 'source ./queuebash.sh >/dev/null 2>&1; queue dev scope-check --file queuebash.sh --allow "queuebash.sh" --json' > /tmp/queue-dev-scope-smoke.json
grep -q '"schema":"queuebash.dev_scope_check_result.v1"' /tmp/queue-dev-scope-smoke.json
grep -q '"status":"pass"' /tmp/queue-dev-scope-smoke.json

if run_bounded bash -lc 'source ./queuebash.sh >/dev/null 2>&1; queue dev scope-check --file queuebash.sh --deny "queuebash.sh" --json' > /tmp/queue-dev-scope-deny.json; then
  echo "scope-check deny should fail" >&2
  exit 1
fi
grep -q '"status":"fail"' /tmp/queue-dev-scope-deny.json
