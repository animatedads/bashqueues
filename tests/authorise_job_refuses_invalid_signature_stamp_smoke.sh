#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
mkdir -p "$root/policies/class-statement" "$root/q/pending"
cat > "$root/policies/class-statement/default.env" <<'POL'
QUEUEBASH_POLICY_KIND=class-statement
QUEUEBASH_POLICY_NAME=default
CLASS_POLICY_AUTHORISATION_SIGNATURE_REQUIRED="if-trusted-key"
CLASS_POLICY_AUTHORISATION_SIGNER_ROOT_PUBLIC_KEY_SHA256="abc"
CLASS_POLICY_AUTHORISATION_SIGNER_ROOT_PUBLIC_KEY_PEM_B64="def"
POL
cat > "$root/q/pending/J123.job" <<'JOB'
JOB_ID=J123
SUBMIT_USER=root
JOB_NAME=demo
COMMAND=( bash publish_to_github.sh )
JOB

export QUEUEBASH_ROOT="$root/q"
export QUEUEBASH_SHARED_POLICY_ROOT="$root/policies"
export QUEUEBASH_SELECTED_USER="hc3"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh

if queue authorise J123 --admin root >"$root/out" 2>"$root/err"; then
    echo "expected queue authorise to refuse an unsigned authorisation required by policy" >&2
    exit 1
fi
grep -q "queue authorise: policy requires a valid signature for admin 'root' but no matching private key could sign this authorisation" "$root/err"
! grep -q '^SECURITY_AUTHORISATION_CODE=' "$root/q/pending/J123.job"
if compgen -G "$root/q/authorisations/*.env" >/dev/null; then
    echo "queue authorise published an invalid authorisation file" >&2
    ls -l "$root/q/authorisations" >&2
    exit 1
fi

echo '[PASS] queue authorise refuses invalid signed-policy candidates before stamping jobs'
