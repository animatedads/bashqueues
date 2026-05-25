#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(mktemp -d)"
POL="$(mktemp -d)"
trap 'rm -rf "$ROOT" "$POL" /tmp/bq_command_block_run.$$ /tmp/bq_command_block_explain.$$ /tmp/bq_command_block_auth.$$' EXIT
mkdir -p "$POL/class-statement"
cat > "$POL/class-statement/cmdblock.env" <<'POLICY'
QUEUEBASH_POLICY_KIND=class-statement
QUEUEBASH_POLICY_NAME=cmdblock
CLASS_POLICY_USER_SANDBOX_POLICIES="off network-none restrict-egress strict queue-default"
CLASS_POLICY_USER_SECCOMP_POLICIES="off docker-default strict queue-default"
CLASS_POLICY_SANDBOX_REASON_REQUIRED="none"
CLASS_POLICY_SECCOMP_REASON_REQUIRED="none"
CLASS_POLICY_BLOCK_COMMAND_WORDS="echo"
CLASS_POLICY_BLOCK_COMMAND_REQUIRE="authorisation"
CLASS_POLICY_AUTHORISATION_SIGNATURE_REQUIRED="off"
POLICY
export QUEUEBASH_ROOT="$ROOT/q"
export QUEUEBASH_SHARED_POLICY_ROOT="$POL"
export QUEUEBASH_CLASS_POLICY_STATEMENT=cmdblock
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh

out="$(queue submit cmdblock -- echo SHOULD_NOT_RUN)"
id="$(printf '%s\n' "$out" | awk '/^Submitted / {print $2}')"
[[ -n "$id" ]]
queue run >/tmp/bq_command_block_run.$$ 2>&1 || true
[[ -f "$QUEUEBASH_ROOT/pol_block/$id.job" ]]
grep -q "command word 'echo' is policy-blocked" "$QUEUEBASH_ROOT/logs/$id.log"
! grep -q '^SHOULD_NOT_RUN$' "$QUEUEBASH_ROOT/logs/$id.log"

queue authorisation generate --admin "$(id -un)" --user "$(id -un)" --reason 'test command block authorisation' -- echo SHOULD_RUN >/tmp/bq_command_block_auth.$$
out2="$(queue submit cmdblock2 -- echo SHOULD_RUN)"
id2="$(printf '%s\n' "$out2" | awk '/^Submitted / {print $2}')"
[[ -n "$id2" ]]
queue run >/tmp/bq_command_block_run.$$ 2>&1 || true
[[ -f "$QUEUEBASH_ROOT/done/$id2.job" ]]
grep -q '^SECURITY_EXEMPTION_TYPE=code-approved$' "$QUEUEBASH_ROOT/done/$id2.job"
grep -q '^SECURITY_EXEMPTION_ACTION=run_with_authorisation$' "$QUEUEBASH_ROOT/done/$id2.job"
queue explain "$id2" >/tmp/bq_command_block_explain.$$ 2>&1 || true
grep -q 'run_with_authorisation' /tmp/bq_command_block_explain.$$
rm -f /tmp/bq_command_block_auth.$$
echo '[PASS] policy command blocks stop unsafe commands and allow exact command-bound authorisation'
