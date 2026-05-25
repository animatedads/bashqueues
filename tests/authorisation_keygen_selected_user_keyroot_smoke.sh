#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v openssl >/dev/null 2>&1; then
    echo '[SKIP] openssl not available for selected-user key-root smoke test'
    exit 0
fi

root="$(mktemp -d)"
trap 'rm -rf "$root" /tmp/bq_keyroot_selected.$$ /tmp/bq_keyroot_selected_out.$$' EXIT
actor_root="$root/actor"
target_root="$root/target"
policy_root="$root/policies"
mkdir -p "$actor_root/keys" "$target_root/pending" "$policy_root/class-statement"

admin="$(id -un 2>/dev/null || echo unknown)"
export QUEUEBASH_ROOT="$target_root"
export QUEUEBASH_SELECTED_USER="targetuser"
export QUEUEBASH_SELECTED_ROOT="$target_root"
export QUEUEBASH_SHARED_POLICY_ROOT="$policy_root"
export QUEUEBASH_AUTHORISATION_KEY_ROOT="$actor_root/keys"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh

queue keygen authorisation "$admin" > /tmp/bq_keyroot_selected.$$
grep -q "private:   $actor_root/keys/private/$admin.ed25519.pem" /tmp/bq_keyroot_selected.$$
test -f "$actor_root/keys/private/$admin.ed25519.pem"
if [[ -e "$target_root/keys/private/$admin.ed25519.pem" ]]; then
    echo 'selected target queue incorrectly received the signer private key' >&2
    exit 1
fi

cat > "$policy_root/class-statement/default.env" <<'POL'
QUEUEBASH_POLICY_KIND=class-statement
QUEUEBASH_POLICY_NAME=default
CLASS_POLICY_AUTHORISATION_SIGNATURE_REQUIRED="if-trusted-key"
POL
grep '^CLASS_POLICY_AUTHORISATION_SIGNER_' /tmp/bq_keyroot_selected.$$ >> "$policy_root/class-statement/default.env"

cat > "$target_root/pending/JKEY.job" <<'JOB'
JOB_ID=JKEY
SUBMIT_USER=root
JOB_NAME=demo
COMMAND=( bash publish_to_github.sh )
JOB

queue authorise JKEY --admin "$admin" --reason 'selected-user signer keyroot' > /tmp/bq_keyroot_selected_out.$$
grep -q '^signature: signed$' /tmp/bq_keyroot_selected_out.$$
grep -q '^integrity: valid-signed$' /tmp/bq_keyroot_selected_out.$$
grep -q '^SECURITY_AUTHORISATION_CODE=' "$target_root/pending/JKEY.job"
if [[ -e "$target_root/keys/private/$admin.ed25519.pem" ]]; then
    echo 'authorise looked under or created keys in the selected target queue' >&2
    exit 1
fi

echo '[PASS] selected-user keygen and authorise use signer key root, not target queue root'
