#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "FAIL: $*" >&2; exit 1; }

grep -Eq '^QUEUEBASH_VERSION="0\.18\.([1-9][0-9][0-9]|[5-9][0-9]|4[3-9])"' queuebash.sh || fail "runtime version guard does not accept the current three-digit 0.18 minor"

for f in \
  tests/edge_cloud_provider_contracts_static.sh \
  tests/ai_advisory_provider_contract_static.sh \
  tests/ask_openai_provider_static.sh \
  tests/queue_dev_contract_static.sh \
  tests/remote_queue_command_static.sh \
  tests/provider_static_version_pin_policy_static.py
do
  [[ -f "$f" ]] || fail "missing guarded file: $f"
  grep -q '\[1-9\]\[0-9\]\[0-9\]' "$f" || fail "$f lacks three-digit 0.18 minor compatibility guard"
done

if grep -RIn 'QUEUEBASH_VERSION.*\[5-9\]\[0-9\]' tests/*_static.sh tests/*_static.py 2>/dev/null \
  | grep -v '\[1-9\]\[0-9\]\[0-9\]' >/dev/null; then
  fail "found stale two-digit-only QUEUEBASH_VERSION guard"
fi

echo "PASS version_guard_three_digit_static"
