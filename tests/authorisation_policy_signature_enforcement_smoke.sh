#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v openssl >/dev/null 2>&1; then
    echo '[SKIP] openssl not available for signed authorisation policy enforcement smoke test'
    exit 0
fi
root="$(mktemp -d)"
trap 'rm -rf "$root" /tmp/bq_auth_policy.$$' EXIT
export QUEUEBASH_ROOT="$root"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh
queue keygen authorisation root > /tmp/bq_auth_policy.$$
queue keygen authorisation hc3 >> /tmp/bq_auth_policy.$$
mkdir -p "$root/policies.d/class-statement"
cp policies.d/class-statement/default.env "$root/policies.d/class-statement/default.env"
grep '^CLASS_POLICY_AUTHORISATION_SIGNER_' /tmp/bq_auth_policy.$$ >> "$root/policies.d/class-statement/default.env"
mkdir -p "$root/authorisations"
cmd_hash="$(_queue_command_hash_from_args bash -lc 'echo signed-required')"
cat > "$root/authorisations/UNS.env" <<EOT
AUTHORISATION_CODE=UNS
AUTHORISATION_ADMIN=hc3
AUTHORISATION_USER=$(id -un)
AUTHORISATION_QUEUE_ROOT=$root
AUTHORISATION_COMMAND_SHA256=$cmd_hash
AUTHORISATION_CREATED_AT=2026-05-25T00:00:00+00:00
AUTHORISATION_EXPIRES_AT=never
AUTHORISATION_STATUS=active
AUTHORISATION_REASON=test
AUTHORISATION_COMMAND=( bash -lc 'echo signed-required' )
EOT
chmod 0444 "$root/authorisations/UNS.env"
out="$(queue authorisation list)"
printf '%s\n' "$out"
grep -q '^UNS .*admin=hc3 .*integrity=invalid-missing-signature' <<< "$out"
cat > "$root/authorisations/ZZZ.env" <<EOT
AUTHORISATION_CODE=ZZZ
AUTHORISATION_ADMIN=unknownadmin
AUTHORISATION_USER=$(id -un)
AUTHORISATION_QUEUE_ROOT=$root
AUTHORISATION_COMMAND_SHA256=$cmd_hash
AUTHORISATION_CREATED_AT=2026-05-25T00:00:00+00:00
AUTHORISATION_EXPIRES_AT=never
AUTHORISATION_STATUS=active
AUTHORISATION_REASON=test
AUTHORISATION_COMMAND=( bash -lc 'echo signed-required' )
EOT
chmod 0444 "$root/authorisations/ZZZ.env"
out="$(queue authorisation list)"
printf '%s\n' "$out"
grep -q '^ZZZ .*admin=unknownadmin .*integrity=invalid-untrusted-admin' <<< "$out"
echo '[PASS] policy-declared public keys make unsigned/untrusted authorisations invalid'
