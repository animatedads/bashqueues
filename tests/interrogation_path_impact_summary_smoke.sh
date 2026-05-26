#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
prof="$tmp/run-001"
mkdir -p "$prof"
cat > "$prof/profile.env" <<'ENV'
PROFILE_ENV_USER=hc3
PROFILE_EFFECTIVE_USER=root
PROFILE_CAPTURED_USER=root
PROFILE_CAPTURED_UID=0
PROFILE_CAPTURED_EUID=0
PROFILE_CAPTURED_HOME=/root
PROFILE_CAPTURED_QUEUE_ROOT=/root/.queuebash
PROFILE_PRIVILEGED_CONTEXT=1
ENV
cat > "$prof/syscalls.raw.trace" <<'TRACE'
123 execve("./install-system.sh", ["./install-system.sh"], 0x7fff) = 0
123 mkdir("/tmp/bashqueues-system-install.123", 0700) = 0
123 openat(AT_FDCWD, "/usr/local/bin/queue", O_WRONLY|O_CREAT|O_TRUNC, 0755) = 3
123 unlinkat(AT_FDCWD, "/usr/local/share/bashqueues/queuebash.sh", 0) = 0
123 openat(AT_FDCWD, "/etc/profile.d/bashqueues.sh", O_WRONLY|O_CREAT|O_TRUNC, 0644) = 3
123 chmod("/usr/local/bin/queue", 0755) = 0
TRACE
: > "$prof/syscalls.summary.txt"
cat > "$prof/lsof.process.trace" <<'LSOF'
COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
bash    123 root cwd DIR  0,0    0        0 /root
bash    123 root txt REG  0,0    0        0 /usr/bin/bash
bash    123 root mem REG  0,0    0        0 /usr/lib64/libc.so.6
LSOF
: > "$prof/net.ss.trace"
: > "$prof/lsof.net.trace"

python3 "$ROOT/bin/queue-interrogate-compile" compile "$prof" --name installprobe --out-root "$tmp/profiles" >/dev/null
file_profile="$tmp/profiles/candidates/installprobe.file.env"
grep -Eq 'FILEPROFILE_PATH_IMPACT=.*system_bin:[^;]*write' "$file_profile" || { echo '[FAIL] system_bin write impact missing' >&2; cat "$file_profile" >&2; exit 1; }
grep -Eq 'FILEPROFILE_PATH_IMPACT=.*system_share:[^;]*delete' "$file_profile" || { echo '[FAIL] system_share delete impact missing' >&2; cat "$file_profile" >&2; exit 1; }
grep -Eq 'FILEPROFILE_PATH_IMPACT=.*system_config:[^;]*write' "$file_profile" || { echo '[FAIL] system_config write impact missing' >&2; cat "$file_profile" >&2; exit 1; }
grep -Eq 'FILEPROFILE_PATH_IMPACT=.*temporary_runtime:[^;]*write' "$file_profile" || { echo '[FAIL] temporary_runtime write impact missing' >&2; cat "$file_profile" >&2; exit 1; }
grep -q 'FILEPROFILE_CAPTURED_EFFECTIVE_USERS=root' "$file_profile" || { echo '[FAIL] effective user missing from file profile' >&2; cat "$file_profile" >&2; exit 1; }
grep -q 'FILEPROFILE_CAPTURED_ENV_USERS=hc3' "$file_profile" || { echo '[FAIL] env user missing from file profile' >&2; cat "$file_profile" >&2; exit 1; }

out="$(python3 "$ROOT/bin/queue-interrogate-compile" explain installprobe --out-root "$tmp/profiles")"
printf '%s\n' "$out" | grep -q 'path impact:' || { echo '[FAIL] explain missing path impact' >&2; printf '%s\n' "$out" >&2; exit 1; }
printf '%s\n' "$out" | grep -q 'system_bin.*write' || { echo '[FAIL] explain missing system_bin write' >&2; printf '%s\n' "$out" >&2; exit 1; }
printf '%s\n' "$out" | grep -q 'system_config.*write' || { echo '[FAIL] explain missing system_config write' >&2; printf '%s\n' "$out" >&2; exit 1; }
printf '%s\n' "$out" | grep -q 'effective_users:.*root' || { echo '[FAIL] explain missing effective root user' >&2; printf '%s\n' "$out" >&2; exit 1; }
printf '%s\n' "$out" | grep -q 'env_users:.*hc3' || { echo '[FAIL] explain missing env user hc3' >&2; printf '%s\n' "$out" >&2; exit 1; }

echo '[PASS] interrogation path impact/effective user smoke checks pass'
