#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$tmp/q"
source ./queuebash.sh

# A shared/default policy requires a reason for weak sandbox level off.  The
# noninteractive default reason is deliberately just reason text, but it should
# let a temporary test queue submit without spelling --reason on every call.
QUEUEBASH_SUBMIT_REASON_DEFAULT='temporary selftest queue under site policy' \
  queue submit t1 --sandbox off -- echo hello >/tmp/bq_nisr_out.$$ 2>/tmp/bq_nisr_err.$$

grep -q '^SECURITY_EXCEPTION_REASON=' "$QUEUEBASH_ROOT"/pending/*.job
grep -q 'temporary\\ selftest\\ queue\\ under\\ site\\ policy' "$QUEUEBASH_ROOT"/pending/*.job

# It must not satisfy an authorisation-only policy.
mkdir -p "$tmp/policies/class-statement"
cat > "$tmp/policies/class-statement/default.env" <<'POL'
QUEUEBASH_POLICY_KIND=class-statement
QUEUEBASH_POLICY_NAME=default
CLASS_POLICY_USER_SANDBOX_POLICIES="off network-none restrict-egress strict queue-default"
CLASS_POLICY_USER_SECCOMP_POLICIES="off docker-default strict queue-default"
CLASS_POLICY_WEAK_POLICY_REQUIRE="authorisation"
CLASS_POLICY_SANDBOX_REASON_REQUIRED="off"
POL
export QUEUEBASH_SHARED_POLICY_ROOT="$tmp/policies"
if QUEUEBASH_SUBMIT_REASON_DEFAULT='not enough for auth-only' queue submit t2 --sandbox off -- echo no >/tmp/bq_nisr_out.$$ 2>/tmp/bq_nisr_err.$$; then
    echo 'expected authorisation-only policy to reject default reason' >&2
    exit 1
fi
grep -qi 'requires --authorisation CODE' /tmp/bq_nisr_err.$$
rm -f /tmp/bq_nisr_out.$$ /tmp/bq_nisr_err.$$

echo '[PASS] noninteractive default reason records audit text and does not bypass auth-only policy'
