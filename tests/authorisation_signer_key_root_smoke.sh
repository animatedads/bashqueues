#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v openssl >/dev/null 2>&1; then
    echo '[SKIP] openssl not available for signer key-root smoke test'
    exit 0
fi

root="$(mktemp -d)"
trap 'rm -rf "$root" /tmp/bq_signer_root_keygen.$$ /tmp/bq_signer_root_out.$$' EXIT
actor_root="$root/actor"
target_root="$root/target"
policy_root="$root/policies"
mkdir -p "$actor_root" "$target_root/pending" "$policy_root/class-statement"

admin="$(id -un 2>/dev/null || echo unknown)"
export QUEUEBASH_ROOT="$target_root"
export QUEUEBASH_SHARED_POLICY_ROOT="$policy_root"
export QUEUEBASH_AUTHORISATION_KEY_ROOT="$actor_root/keys"
export QUEUEBASH_SELECTED_USER="targetuser"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh

queue keygen authorisation "$admin" > /tmp/bq_signer_root_keygen.$$
test -f "$actor_root/keys/private/$admin.ed25519.pem"
if [[ -e "$target_root/keys/private/$admin.ed25519.pem" ]]; then
    echo 'signing key was incorrectly generated under selected target queue root' >&2
    exit 1
fi

cat > "$policy_root/class-statement/default.env" <<'POL'
QUEUEBASH_POLICY_KIND=class-statement
QUEUEBASH_POLICY_NAME=default
CLASS_POLICY_AUTHORISATION_SIGNATURE_REQUIRED="if-trusted-key"
POL
grep '^CLASS_POLICY_AUTHORISATION_SIGNER_' /tmp/bq_signer_root_keygen.$$ >> "$policy_root/class-statement/default.env"

cat > "$target_root/pending/J123.job" <<'JOB'
JOB_ID=J123
SUBMIT_USER=root
JOB_NAME=demo
COMMAND=( bash publish_to_github.sh )
JOB

queue authorise J123 --admin "$admin" --reason 'signed from actor key root' > /tmp/bq_signer_root_out.$$
grep -q '^signature: signed$' /tmp/bq_signer_root_out.$$
grep -q '^integrity: valid-signed$' /tmp/bq_signer_root_out.$$
test -f "$target_root/authorisations/"*.env
if [[ -e "$target_root/keys/private/$admin.ed25519.pem" ]]; then
    echo 'queue authorise looked for or created a signing key under selected target queue root' >&2
    exit 1
fi
queue authorisation list > /tmp/bq_signer_root_out.$$
grep -q 'integrity=valid-signed' /tmp/bq_signer_root_out.$$
grep -q '^SECURITY_AUTHORISATION_CODE=' "$target_root/pending/J123.job"

echo '[PASS] authorisation signing uses signer key root rather than selected queue root'
