#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(mktemp -d)"
POL="$(mktemp -d)"
trap 'rm -rf "$ROOT" "$POL"' EXIT
mkdir -p "$POL/class-statement"
cat > "$POL/class-statement/default.env" <<'POLICY'
QUEUEBASH_POLICY_KIND=class-statement
QUEUEBASH_POLICY_NAME=default
CLASS_POLICY_USER_SANDBOX_POLICIES="off network-none restrict-egress strict queue-default"
CLASS_POLICY_USER_SECCOMP_POLICIES="off docker-default strict queue-default"
CLASS_POLICY_EXCEPTION_FLAGS_REQUIRE="reason-or-authorisation"
CLASS_POLICY_WEAK_POLICY_REQUIRE="reason-or-authorisation"
CLASS_POLICY_SANDBOX_REASON_REQUIRED="off"
CLASS_POLICY_AUTHORISATION_SIGNATURE_REQUIRED="off"
POLICY
export QUEUEBASH_ROOT="$ROOT/q"
export QUEUEBASH_SHARED_POLICY_ROOT="$POL"
export QUEUEBASH_CLASS_POLICY_STATEMENT=default
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh

# Submit-time reason is accepted for audit, but worker-side execution policy now
# requires a valid command-bound authorisation or standing grant for a contrary job.
out="$(queue submit weak_with_reason --reason 'audit only' -- bash -c 'echo SHOULD_NOT_RUN')"
id="$(printf '%s\n' "$out" | awk '/^Submitted / {print $2}')"
[[ -n "$id" ]]
queue run >/tmp/bq_pol_blocked_run.$$ 2>&1 || true
[[ -f "$QUEUEBASH_ROOT/pol_blocked/$id.job" ]]
[[ ! -f "$QUEUEBASH_ROOT/failed/$id.job" ]]
[[ ! -f "$QUEUEBASH_ROOT/done/$id.job" ]]
grep -q '^POLICY_BLOCKED=1$' "$QUEUEBASH_ROOT/pol_blocked/$id.job"
grep -q 'POLICY_BLOCKED' "$QUEUEBASH_ROOT/logs/$id.log"
grep -q 'No class claims, asset preflight checks' "$QUEUEBASH_ROOT/logs/$id.log"
! grep -q 'SHOULD_NOT_RUN' "$QUEUEBASH_ROOT/logs/$id.log"
rm -f /tmp/bq_pol_blocked_run.$$

echo '[PASS] policy-contrary jobs move to pol_blocked without running or retrying'
