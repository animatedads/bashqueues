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

source "$ROOT/queuebash.sh"

make_candidates selfdev
python3 "$ROOT/bin/queue-interrogate-compile" approve selfdev --accept-warnings --accept-risk --signing-key self:dev >/dev/null

allowed="$(_queue_profiled_seccomp_allowed_syscalls selfdev 1 '' '')" || fail 'allowed self-signed profiled syscall extraction failed'
[[ "$allowed" == 'read write exit_group' ]] || fail "unexpected syscall list: $allowed"

if _queue_profiled_seccomp_allowed_syscalls selfdev 0 '' '' >/tmp/sec-denied.out 2>&1; then
  fail 'self-signed secprofile accepted when allow_self_signed=0'
fi
grep -q 'self_signed_not_allowed' /tmp/sec-denied.out || fail 'self-signed rejection did not explain trust reason'

SECCOMP_PROFILED_ALLOWED_SYSCALLS="$allowed"
mapfile -d '' props < <(_queue_emit_seccomp_systemd_props '' '')
printf '%s\n' "${props[@]}" >/tmp/sec-props.out
grep -q -- '-p' /tmp/sec-props.out || fail 'systemd property flag missing'
grep -q 'SystemCallFilter=read write exit_group' /tmp/sec-props.out || fail 'SystemCallFilter property missing'

queue profile interrogate class-template SECURE_SELF_ALLOWED --profile selfdev --allow-self-signed 1 --force >/tmp/class-template.out
class_file="$QUEUEBASH_ROOT/classes/SECURE_SELF_ALLOWED.env"
grep -q 'CLASS_DEFAULT_SECCOMP_PROFILED_NAME=selfdev' "$class_file" || fail 'generated class missing profiled seccomp name'
grep -q 'CLASS_DEFAULT_SECCOMP_PROFILED_ENFORCE=1' "$class_file" || fail 'generated class missing profiled seccomp enforcement'
_queue_class_load_defaults_for_class SECURE_SELF_ALLOWED >/tmp/class-defaults.out || true
grep -q $'SECCOMP_PROFILED_NAME\tselfdev' /tmp/class-defaults.out || fail 'class defaults did not expose profiled seccomp name'
grep -q $'SECCOMP_PROFILED_ENFORCE\t1' /tmp/class-defaults.out || fail 'class defaults did not expose profiled seccomp enforcement'

echo '# tamper' >> "$QUEUEBASH_ROOT/profiles/interrogation/approved/selfdev.seccomp.env"
if _queue_profiled_seccomp_allowed_syscalls selfdev 1 '' '' >/tmp/sec-tamper.out 2>&1; then
  fail 'tampered secprofile accepted by runtime extraction'
fi
grep -q 'signature_mismatch' /tmp/sec-tamper.out || fail 'tamper rejection did not explain signature mismatch'

echo '[PASS] runtime seccomp generated profiles smoke checks pass'
