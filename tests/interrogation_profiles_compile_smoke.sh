#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_PLUGIN_SOURCE_DIR="$ROOT/assets.d"
mkdir -p "$QUEUEBASH_ROOT/assets.d"
cp "$ROOT/assets.d/secprofile.sh" "$ROOT/assets.d/netprofile.sh" "$ROOT/assets.d/fileprofile.sh" "$QUEUEBASH_ROOT/assets.d/"
mkdir -p "$QUEUEBASH_ROOT/profiles/interrogation/runs/sample"
run="$QUEUEBASH_ROOT/profiles/interrogation/runs/sample"
cat > "$run/syscalls.raw.trace" <<'EOF'
123 execve("/bin/rm", ["rm", "x"], 0x7ffc) = 0
123 openat(AT_FDCWD, "/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 3
123 unlinkat(AT_FDCWD, "x", 0) = 0
123 close(3) = 0
EOF
cat > "$run/net.ss.trace" <<'EOF'
tcp ESTAB 0 0 10.0.0.1:43210 93.184.216.34:80 users:(("wget",pid=123,fd=3))
EOF
cat > "$run/lsof.process.trace" <<'EOF'
COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
wget    123 hc3 txt REG 8,1 1234 55 /usr/bin/wget
wget    123 hc3 mem REG 8,1 1234 56 /etc/ssl/certs/ca-certificates.crt
wget    123 hc3 3u IPv4 12345 0t0 TCP 10.0.0.1:43210->93.184.216.34:80 (ESTABLISHED)
EOF
python3 "$ROOT/bin/queue-interrogate-compile" compile "$run" --name sample --json >/tmp/interrogation_compile.json
[[ -f "$QUEUEBASH_ROOT/profiles/interrogation/candidates/sample.seccomp.env" ]]
grep -q 'SECPROFILE_SHOULD_BE_SIGNED=1' "$QUEUEBASH_ROOT/profiles/interrogation/candidates/sample.seccomp.env"
grep -q 'unlinkat' "$QUEUEBASH_ROOT/profiles/interrogation/candidates/sample.seccomp.env"
python3 "$ROOT/bin/queue-interrogate-compile" approve sample --accept-warnings --accept-risk --json >/tmp/interrogation_approve.json
[[ -f "$QUEUEBASH_ROOT/profiles/interrogation/approved/sample.seccomp.env" ]]
grep -q 'SECPROFILE_STATUS=approved' "$QUEUEBASH_ROOT/profiles/interrogation/approved/sample.seccomp.env"
grep -q 'SECPROFILE_SIGNED=1' "$QUEUEBASH_ROOT/profiles/interrogation/approved/sample.seccomp.env"
source "$ROOT/queuebash.sh"
out="$(_queue_asset_implied_preflight_args secprofile:profile_verified secprofile profile_verified sample)"
grep -q 'asset_check_ok' <<<"$out"
out="$(_queue_asset_implied_preflight_args netprofile:profile_verified netprofile profile_verified sample)"
grep -q 'asset_check_ok' <<<"$out"
out="$(_queue_asset_implied_preflight_args fileprofile:profile_verified fileprofile profile_verified sample)"
grep -q 'asset_check_ok' <<<"$out"
# Tamper must be detected.
printf '\nSECPROFILE_ALLOWED_SYSCALLS=execve,openat,unlinkat,close,socket\n' >> "$QUEUEBASH_ROOT/profiles/interrogation/approved/sample.seccomp.env"
if _queue_asset_implied_preflight_args secprofile:profile_verified secprofile profile_verified sample >/dev/null 2>&1; then
  echo '[FAIL] tampered secprofile unexpectedly verified' >&2
  exit 1
fi
echo '[PASS] interrogation profile compile smoke checks pass'
