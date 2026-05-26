#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"
run="$QUEUEBASH_ROOT/profiles/interrogation/runs/filepaths"
mkdir -p "$run"
cat > "$run/profile.env" <<'EOF'
PROFILE_RUN_ID=filepaths
EOF
cat > "$run/syscalls.raw.trace" <<'EOF'
100 execve("/usr/bin/rexx", ["rexx", "bad.rex"], 0x7ffc) = 0
100 openat(AT_FDCWD, "/tmp/counter.txt", O_WRONLY|O_CREAT|O_TRUNC, 0666) = 3
100 write(3, "1\n", 2) = 2
100 close(3) = 0
100 unlink("/tmp/counter.txt") = 0
100 mkdir("/tmp/bashqueues_test_dir", 0777) = 0
100 wait4(101, [{WIFEXITED(s) && WEXITSTATUS(s) == 0}], 0, NULL) = 101
EOF
cat > "$run/lsof.process.trace" <<'EOF'
COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
rexx    100 hc3 txt REG 8,1 1234 55 /usr/bin/rexx
rexx    100 hc3 mem REG 8,1 1234 56 /usr/lib64/libc.so.6
rexx    100 hc3 3r  REG 8,1 1234 57 /home/hc3/bad.rex
EOF
: > "$run/net.ss.trace"
: > "$run/lsof.net.trace"
python3 "$ROOT/bin/queue-interrogate-compile" compile "$run" --name filepaths >/tmp/compile.out
file="$QUEUEBASH_ROOT/profiles/interrogation/candidates/filepaths.file.env"
sec="$QUEUEBASH_ROOT/profiles/interrogation/candidates/filepaths.seccomp.env"
grep -q '^FILEPROFILE_OBSERVED_DELETE_PATHS=/tmp/counter.txt$' "$file" || { echo '[FAIL] delete path not recorded' >&2; cat "$file" >&2; exit 1; }
grep -q '^FILEPROFILE_OBSERVED_WRITE_PATHS=/tmp/bashqueues_test_dir,/tmp/counter.txt$' "$file" || { echo '[FAIL] write/create paths not recorded' >&2; cat "$file" >&2; exit 1; }
if grep -q 'WEXITSTATUS' "$sec"; then
  echo '[FAIL] WEXITSTATUS leaked into seccomp candidate' >&2
  exit 1
fi
explain="$(python3 "$ROOT/bin/queue-interrogate-compile" explain filepaths)"
grep -q 'observed_delete_paths: /tmp/counter.txt' <<<"$explain" || { echo '[FAIL] explain omitted delete path' >&2; printf '%s\n' "$explain" >&2; exit 1; }
grep -q 'observed_write_paths:  /tmp/bashqueues_test_dir,/tmp/counter.txt' <<<"$explain" || { echo '[FAIL] explain omitted write paths' >&2; printf '%s\n' "$explain" >&2; exit 1; }
grep -q 'destructive syscall path evidence observed: /tmp/counter.txt' <<<"$explain" || { echo '[FAIL] explain omitted destructive path note' >&2; printf '%s\n' "$explain" >&2; exit 1; }
echo '[PASS] interrogation file path review smoke checks pass'
