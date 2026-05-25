#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(mktemp -d)"
POL="$(mktemp -d)"
trap 'rm -rf "$ROOT" "$POL"' EXIT
mkdir -p "$POL/class-statement"
cp policies.d/class-statement/policyblock-test.env "$POL/class-statement/policyblock-test.env"
export QUEUEBASH_ROOT="$ROOT/q"
export QUEUEBASH_SHARED_POLICY_ROOT="$POL"
export QUEUEBASH_CLASS_POLICY_STATEMENT=policyblock-test
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh

out="$(queue submit pbtest --class POLICYBLOCKED --reason 'submit audit only' -- bash -c 'echo SHOULD_NOT_RUN')"
id="$(printf '%s\n' "$out" | awk '/^Submitted / {print $2}')"
[[ -n "$id" ]]
queue sentinel --once >/tmp/bq_sentinel_policy.$$ 2>&1 || true
[[ -f "$QUEUEBASH_ROOT/pol_block/$id.job" ]]
[[ ! -f "$QUEUEBASH_ROOT/pending/$id.job" ]]
[[ ! -f "$QUEUEBASH_ROOT/running/$id.job" ]]
grep -q '^POLICY_BLOCKED=1$' "$QUEUEBASH_ROOT/pol_block/$id.job"
grep -q '^POLICY_BLOCKED_BY=sentinel$' "$QUEUEBASH_ROOT/pol_block/$id.job"
grep -q 'Blocked by cheap sentinel policy gate' "$QUEUEBASH_ROOT/logs/$id.log"
! grep -q 'SHOULD_NOT_RUN' "$QUEUEBASH_ROOT/logs/$id.log"
rm -f /tmp/bq_sentinel_policy.$$

echo '[PASS] sentinel moves policy-contrary pending jobs to pol_block without a worker'
