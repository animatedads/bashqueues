#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v openssl >/dev/null 2>&1; then
    echo '[SKIP] openssl not available for Ed25519 signed authorisation smoke test'
    exit 0
fi

root="$(mktemp -d)"
trap 'rm -rf "$root" /tmp/bq_signed_auth_out.$$ /tmp/bq_signed_auth_err.$$' EXIT
export QUEUEBASH_ROOT="$root"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh

queue keygen authorisation root > /tmp/bq_signed_auth_out.$$
test -f "$root/keys/private/root.ed25519.pem"
test -f "$root/keys/public/root.ed25519.pub.pem"
mode="$(stat -c '%a' "$root/keys/private/root.ed25519.pem" 2>/dev/null || stat -f '%Lp' "$root/keys/private/root.ed25519.pem")"
[[ "$mode" == "600" ]]

mkdir -p "$root/policies.d/class-statement"
cp policies.d/class-statement/default.env "$root/policies.d/class-statement/default.env"
grep '^CLASS_POLICY_AUTHORISATION_SIGNER_ROOT' /tmp/bq_signed_auth_out.$$ >> "$root/policies.d/class-statement/default.env"

code="$(queue authorisation generate --admin root --user "$(id -un)" --code K9 --reason signed-test -- bash -lc 'echo signed' | awk '/authorisation:/ {print $2}')"
[[ "$code" == "K9" ]]
queue authorisation list > /tmp/bq_signed_auth_out.$$
grep -q 'integrity=valid-signed' /tmp/bq_signed_auth_out.$$
queue submit signedok --sandbox-override off --authorisation k9 -- bash -lc 'echo signed' >/tmp/bq_signed_auth_out.$$ 2>/tmp/bq_signed_auth_err.$$

sed -i 's/AUTHORISATION_USER=.*/AUTHORISATION_USER=tampered/' "$root/authorisations/K9.env"
queue authorisation list > /tmp/bq_signed_auth_out.$$ || true
grep -q 'integrity=invalid-payload-hash' /tmp/bq_signed_auth_out.$$
if queue submit signedbad --sandbox-override off --authorisation K9 -- bash -lc 'echo signed' >/tmp/bq_signed_auth_out.$$ 2>/tmp/bq_signed_auth_err.$$; then
    echo 'expected tampered signed authorisation to fail' >&2
    exit 1
fi
grep -qi 'signature check failed\|authorisation K9 is for user' /tmp/bq_signed_auth_err.$$

echo '[PASS] signed authorisation keys verify against policy-declared public keys and detect tampering'
