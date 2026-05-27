#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

export QUEUEBASH_ROOT="$(mktemp -d)"
trap 'rm -rf "$QUEUEBASH_ROOT"' EXIT
mkdir -p "$QUEUEBASH_ROOT/profiles/interrogation/candidates" "$QUEUEBASH_ROOT/keys/private" "$QUEUEBASH_ROOT/keys/public"

openssl genpkey -algorithm ED25519 -out "$QUEUEBASH_ROOT/keys/private/ops-release.ed25519.pem" >/dev/null 2>&1
openssl pkey -in "$QUEUEBASH_ROOT/keys/private/ops-release.ed25519.pem" -pubout -out "$QUEUEBASH_ROOT/keys/public/ops-release.ed25519.pub.pem" >/dev/null 2>&1

for kind in seccomp net file; do
  case "$kind" in
    seccomp) pre=SECPROFILE; extra='SECPROFILE_ALLOWED_SYSCALLS=read,write,exit_group
SECPROFILE_DEFAULT_ACTION=kill' ;;
    net) pre=NETPROFILE; extra='NETPROFILE_ALLOWED_PROTOCOLS=
NETPROFILE_ALLOWED_REMOTE_PORTS=
NETPROFILE_ALLOWED_REMOTE_HOSTS=' ;;
    file) pre=FILEPROFILE; extra='FILEPROFILE_ALLOWED_READ_PREFIXES=/usr/bin
FILEPROFILE_ALLOW_DELETED_FILES=0' ;;
  esac
  {
    echo "${pre}_NAME=edtest"
    echo "${pre}_STATUS=candidate"
    echo "${pre}_SHOULD_BE_SIGNED=1"
    echo "${pre}_SIGNED=0"
    echo "$extra"
  } > "$QUEUEBASH_ROOT/profiles/interrogation/candidates/edtest.$kind.env"
done

python3 bin/queue-interrogate-compile approve edtest --signing-key ops-release --accept-warnings --accept-risk >/tmp/edtest.approve
python3 bin/queue-interrogate-compile verify edtest --allow-self-signed 0 --required-signer ops-release >/tmp/edtest.verify

grep -q 'verified: 1' /tmp/edtest.verify || fail 'verified profile not accepted'
grep -q 'ed25519_valid=1' /tmp/edtest.verify || fail 'ed25519 signature not verified'
grep -q 'SECPROFILE_SIGNATURE_ALG=ed25519' "$QUEUEBASH_ROOT/profiles/interrogation/approved/edtest.seccomp.env" || fail 'seccomp profile not ed25519 signed'

source assets.d/secprofile.sh
queue_asset_check_secprofile_profile_verified _ edtest allow_self_signed=0 required_signer=ops-release >/tmp/edtest.asset || fail 'secprofile asset rejected valid ed25519 profile'

echo '# tamper' >> "$QUEUEBASH_ROOT/profiles/interrogation/approved/edtest.seccomp.env"
if queue_asset_check_secprofile_profile_verified _ edtest allow_self_signed=0 required_signer=ops-release >/tmp/edtest.asset2 2>&1; then
  fail 'tampered profile was accepted'
fi

echo '[PASS] interrogation Ed25519 profile signing smoke checks pass'
