#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
export QUEUEBASH_ROOT="$root"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh

if queue submit blocked --sandbox-override off -- echo blocked >/tmp/bq_policy_out.$$ 2>/tmp/bq_policy_err.$$; then
    cat /tmp/bq_policy_out.$$
    echo "expected submit without reason/authorisation to fail" >&2
    exit 1
fi
grep -qi 'requires --reason TEXT or --authorisation CODE' /tmp/bq_policy_err.$$

queue submit allowed --sandbox-override off --reason 'one-off network test' -- echo allowed >/tmp/bq_policy_out.$$
grep -q '^EXCEPTION_SANDBOX_OVERRIDE=off$' "$root"/pending/*.job
grep -q '^SECURITY_EXCEPTION_REASON=' "$root"/pending/*.job

code="$(queue authorisation generate --admin admin --user "$(id -un)" --code Z9 -- bash -lc 'echo authorised' | awk '/authorisation:/ {print $2}')"
[[ "$code" == "Z9" ]]
queue submit authok --sandbox-override off --authorisation z9 -- bash -lc 'echo authorised' >/tmp/bq_policy_out.$$

if queue submit authbad --sandbox-override off --authorisation z9 -- bash -lc 'echo different' >/tmp/bq_policy_out.$$ 2>/tmp/bq_policy_err.$$; then
    echo "expected command-bound authorisation mismatch to fail" >&2
    exit 1
fi
grep -qi 'does not match this command' /tmp/bq_policy_err.$$
rm -f /tmp/bq_policy_out.$$ /tmp/bq_policy_err.$$
echo '[PASS] policy reason and command-bound authorisation enforcement works'
