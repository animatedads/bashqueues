#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
fail(){ echo "[FAIL] $*" >&2; exit 1; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
mkdir -p "$QUEUEBASH_ROOT/assets.d" "$QUEUEBASH_ROOT/profiles/interrogation/candidates" "$QUEUEBASH_ROOT/keys/private" "$QUEUEBASH_ROOT/keys/public" "$QUEUEBASH_ROOT/pending"
cp "$ROOT/assets.d/secprofile.sh" "$ROOT/assets.d/netprofile.sh" "$ROOT/assets.d/fileprofile.sh" "$QUEUEBASH_ROOT/assets.d/"

make_candidates() {
  local name="$1"
  for kind in seccomp net file; do
    case "$kind" in
      seccomp) pre=SECPROFILE; extra='SECPROFILE_ALLOWED_SYSCALLS=read,write,exit_group
SECPROFILE_DEFAULT_ACTION=kill' ;;
      net) pre=NETPROFILE; extra='NETPROFILE_ALLOWED_PROTOCOLS=
NETPROFILE_ALLOWED_REMOTE_PORTS=
NETPROFILE_ALLOWED_REMOTE_HOSTS=' ;;
      file) pre=FILEPROFILE; extra='FILEPROFILE_ALLOWED_READ_PREFIXES=/usr/bin
FILEPROFILE_ALLOWED_WRITE_PREFIXES=
FILEPROFILE_ALLOW_DELETED_FILES=0' ;;
    esac
    {
      echo "${pre}_NAME=$name"
      echo "${pre}_STATUS=candidate"
      echo "${pre}_SHOULD_BE_SIGNED=1"
      echo "${pre}_SIGNED=0"
      echo "$extra"
    } > "$QUEUEBASH_ROOT/profiles/interrogation/candidates/$name.$kind.env"
  done
}

make_job() {
  local class="$1" job
  job="$QUEUEBASH_ROOT/pending/${class}.job"
  cat > "$job" <<JOB
JOB_ID=${class}
JOB_NAME=${class}
JOB_CLASS=${class}
COMMAND_LINE=true
JOB
  printf '%s\n' "$job"
}

source "$ROOT/queuebash.sh"

# Self-signed profiles are useful for development but secure classes must be able
# to reject them by policy.
make_candidates selfdev
python3 "$ROOT/bin/queue-interrogate-compile" approve selfdev --accept-warnings --accept-risk --signing-key self:dev >/dev/null
queue profile interrogate class-template SECURE_SELF_DENIED --profile selfdev --allow-self-signed 0 --force >/tmp/class-self-denied.out
job="$(make_job SECURE_SELF_DENIED)"
if _queue_class_available "$job" >/tmp/self-denied.out 2>&1; then
  fail 'secure class accepted self-signed profile when allow-self-signed=0'
fi
grep -q 'self_signed_not_allowed' /tmp/self-denied.out || fail 'self-signed class block did not explain rejection'

queue profile interrogate class-template SECURE_SELF_ALLOWED --profile selfdev --allow-self-signed 1 --force >/tmp/class-self-allowed.out
job="$(make_job SECURE_SELF_ALLOWED)"
_queue_class_available "$job" >/tmp/self-allowed.out 2>&1 || { cat /tmp/self-allowed.out >&2; fail 'secure class rejected allowed self-signed profile'; }

# Real Ed25519 signer should pass when required_signer matches and block when it does not.
openssl genpkey -algorithm ED25519 -out "$QUEUEBASH_ROOT/keys/private/ops-release.ed25519.pem" >/dev/null 2>&1
openssl pkey -in "$QUEUEBASH_ROOT/keys/private/ops-release.ed25519.pem" -pubout -out "$QUEUEBASH_ROOT/keys/public/ops-release.ed25519.pub.pem" >/dev/null 2>&1
make_candidates edclass
python3 "$ROOT/bin/queue-interrogate-compile" approve edclass --accept-warnings --accept-risk --signing-key ops-release >/dev/null
queue profile interrogate class-template SECURE_ED_OK --profile edclass --required-signer ops-release --allow-self-signed 0 --force >/tmp/class-ed-ok.out
job="$(make_job SECURE_ED_OK)"
_queue_class_available "$job" >/tmp/ed-ok.out 2>&1 || { cat /tmp/ed-ok.out >&2; fail 'secure class rejected required Ed25519 signer'; }

grep -q 'queue_class_shared_asset secprofile profile_verified "$PROFILE_NAME"' "$QUEUEBASH_ROOT/classes/SECURE_ED_OK.env" || fail 'generated class missing secprofile gate'
grep -q 'PROFILE_REQUIRED_SIGNER=ops-release' "$QUEUEBASH_ROOT/classes/SECURE_ED_OK.env" || fail 'generated class missing required signer'

queue profile interrogate class-template SECURE_ED_BAD_SIGNER --profile edclass --required-signer other-release --allow-self-signed 0 --force >/tmp/class-ed-bad.out
job="$(make_job SECURE_ED_BAD_SIGNER)"
if _queue_class_available "$job" >/tmp/ed-bad.out 2>&1; then
  fail 'secure class accepted profile signed by the wrong required signer'
fi
grep -q 'signer_not_required' /tmp/ed-bad.out || fail 'wrong signer class block did not explain rejection'

# Tampering an approved file must make the class gate fail before dispatch.
echo '# tamper' >> "$QUEUEBASH_ROOT/profiles/interrogation/approved/edclass.seccomp.env"
job="$(make_job SECURE_ED_OK)"
if _queue_class_available "$job" >/tmp/tamper.out 2>&1; then
  fail 'secure class accepted tampered approved profile'
fi
grep -q 'signature_mismatch' /tmp/tamper.out || fail 'tampered class block did not explain signature mismatch'

echo '[PASS] secure profiled class gate smoke checks pass'
