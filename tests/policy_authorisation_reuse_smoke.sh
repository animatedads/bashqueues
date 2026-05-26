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
CLASS_POLICY_EXCEPTION_FLAGS_REQUIRE="authorisation"
CLASS_POLICY_WEAK_POLICY_REQUIRE="authorisation"
CLASS_POLICY_SANDBOX_REASON_REQUIRED="off"
CLASS_POLICY_AUTHORISATION_SIGNATURE_REQUIRED="off"
POLICY
export QUEUEBASH_ROOT="$ROOT/q"
export QUEUEBASH_SHARED_POLICY_ROOT="$POL"
export QUEUEBASH_CLASS_POLICY_STATEMENT=default
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh

queue authorisation generate --admin root --user "$(id -un)" --expires never -- bash -c 'echo REUSABLE' >"$ROOT/auth.out"
code="$(awk '/^authorisation:/ {print $2}' "$ROOT/auth.out")"
[[ -n "$code" ]]

out1="$(queue submit reuse1 --authorisation "$code" -- bash -c 'echo REUSABLE')"
id1="$(printf '%s\n' "$out1" | awk '/^Submitted / {print $2}')"
out2="$(queue submit reuse2 --authorisation "$code" -- bash -c 'echo REUSABLE')"
id2="$(printf '%s\n' "$out2" | awk '/^Submitted / {print $2}')"
queue run >/tmp/bq_policy_reuse_run.$$ 2>&1 || true
[[ -f "$QUEUEBASH_ROOT/done/$id1.job" ]]
[[ -f "$QUEUEBASH_ROOT/done/$id2.job" ]]
grep -q '^SECURITY_AUTHORISATION_CODE=' "$QUEUEBASH_ROOT/done/$id1.job"
grep -q '^SECURITY_AUTHORISATION_CODE=' "$QUEUEBASH_ROOT/done/$id2.job"
rm -f /tmp/bq_policy_reuse_run.$$

echo '[PASS] one valid command-bound authorisation can be reused for repeated resubmissions until expiry'
