#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
fail(){ echo "[FAIL] $*" >&2; exit 1; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_PLUGIN_SOURCE_DIR="$ROOT/assets.d"
mkdir -p "$QUEUEBASH_ROOT/assets.d" "$QUEUEBASH_ROOT/profiles/interrogation/runs/sample"
cp "$ROOT/assets.d/secprofile.sh" "$ROOT/assets.d/netprofile.sh" "$ROOT/assets.d/fileprofile.sh" "$QUEUEBASH_ROOT/assets.d/"
run="$QUEUEBASH_ROOT/profiles/interrogation/runs/sample"
cat > "$run/syscalls.raw.trace" <<'TRACE'
123 execve("/usr/bin/rexx", ["rexx", "good.rex"], 0x7ffc) = 0
123 openat(AT_FDCWD, "/home/hc3/good.rex", O_RDONLY) = 3
123 close(3) = 0
TRACE
cat > "$run/lsof.process.trace" <<'TRACE'
COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
rexx    123 hc3 txt REG 8,1 1234 55 /usr/bin/rexx
rexx    123 hc3 mem REG 8,1 1234 56 /usr/lib64/libc.so.6
TRACE
python3 "$ROOT/bin/queue-interrogate-compile" compile "$run" --name sample >/dev/null
python3 "$ROOT/bin/queue-interrogate-compile" approve sample --accept-warnings --signing-key self:unit >/dev/null
python3 "$ROOT/bin/queue-interrogate-compile" verify sample >/tmp/verify.out
 grep -q 'verified: 1' /tmp/verify.out || fail 'verify command did not accept fresh profile'
if python3 "$ROOT/bin/queue-interrogate-compile" verify sample --allow-self-signed 0 >/tmp/verify-noself.out 2>&1; then
  fail 'verify unexpectedly accepted self-signed profile with allow-self-signed=0'
fi
grep -q 'self_signed_not_allowed' /tmp/verify-noself.out || fail 'verify did not explain self-signed rejection'
python3 "$ROOT/bin/queue-interrogate-compile" verify sample --required-signer self:unit >/tmp/verify-required.out
 grep -q 'verified: 1' /tmp/verify-required.out || fail 'required signer did not pass'
if python3 "$ROOT/bin/queue-interrogate-compile" verify sample --required-signer ops-release >/tmp/verify-badsigner.out 2>&1; then
  fail 'verify unexpectedly accepted wrong required signer'
fi
grep -q 'signer_not_required' /tmp/verify-badsigner.out || fail 'verify did not explain signer rejection'
source "$ROOT/queuebash.sh"
out="$(_queue_asset_implied_preflight_args secprofile:profile_verified secprofile profile_verified sample required_signer=self:unit)"
grep -q 'asset_check_ok' <<<"$out" || fail 'secprofile required_signer did not pass'
if _queue_asset_implied_preflight_args secprofile:profile_verified secprofile profile_verified sample allow_self_signed=0 >/tmp/asset-noself.out 2>&1; then
  fail 'asset unexpectedly accepted self-signed profile with allow_self_signed=0'
fi
grep -q 'self_signed_not_allowed' /tmp/asset-noself.out || fail 'asset did not explain self-signed block'
# Tamper must be caught by both CLI and asset.
printf '\nSECPROFILE_ALLOWED_SYSCALLS=execve,openat,close,unlink\n' >> "$QUEUEBASH_ROOT/profiles/interrogation/approved/sample.seccomp.env"
if python3 "$ROOT/bin/queue-interrogate-compile" verify sample --kind seccomp >/tmp/verify-tamper.out 2>&1; then
  fail 'verify unexpectedly accepted tampered profile'
fi
grep -q 'signature_mismatch' /tmp/verify-tamper.out || fail 'verify did not show signature mismatch'
if _queue_asset_implied_preflight_args secprofile:profile_verified secprofile profile_verified sample >/tmp/asset-tamper.out 2>&1; then
  fail 'asset unexpectedly accepted tampered profile'
fi
grep -q 'signature_mismatch' /tmp/asset-tamper.out || fail 'asset did not show signature mismatch'
echo '[PASS] interrogation signature verification smoke checks pass'
