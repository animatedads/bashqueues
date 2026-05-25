#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/policies/class-statement"
cat > "$tmp/policies/class-statement/default.env" <<'POL'
QUEUEBASH_POLICY_KIND=class-statement
QUEUEBASH_POLICY_NAME=default
CLASS_POLICY_AUTHORISATION_SIGNATURE_REQUIRED="if-trusted-key"
CLASS_POLICY_AUTHORISATION_SIGNER_ROOT_PUBLIC_KEY_SHA256="abc"
CLASS_POLICY_AUTHORISATION_SIGNER_ROOT_PUBLIC_KEY_PEM_B64="def"
POL

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$tmp/q"
export QUEUEBASH_SHARED_POLICY_ROOT="$tmp/policies"
source ./queuebash.sh

policy_out="$(queue authorisation policy)"
grep -q 'policy_file:' <<<"$policy_out"
grep -q 'trusted_signers: ROOT' <<<"$policy_out"

if queue authorisation generate --admin root --user hc3 --reason test -- echo hello >"$tmp/out" 2>"$tmp/err"; then
    echo "expected root authorisation without matching private key to fail" >&2
    exit 1
fi
grep -q "policy requires a valid signature for admin 'root'" "$tmp/err"

if queue authorisation generate --admin hc3 --user hc3 --reason test -- echo hello >"$tmp/out" 2>"$tmp/err"; then
    echo "expected undeclared hc3 authorisation to fail when trust list exists" >&2
    exit 1
fi
grep -q "admin 'hc3' is not trusted" "$tmp/err"

echo '[PASS] policy trust list blocks unsigned trusted admins and undeclared admins at generation time'
