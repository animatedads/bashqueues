#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"
run="$QUEUEBASH_ROOT/profiles/interrogation/runs/rootish"
mkdir -p "$run"
cat > "$run/profile.env" <<'PEOF'
PROFILE_RUN_ID=rootish
PROFILE_CAPTURED_USER=root
PROFILE_CAPTURED_UID=0
PROFILE_CAPTURED_EUID=0
PROFILE_CAPTURED_HOME=/root
PROFILE_CAPTURED_QUEUE_ROOT=/root/.queuebash
PROFILE_PRIVILEGED_CONTEXT=1
PEOF
cat > "$run/syscalls.raw.trace" <<'TEOF'
100 execve("/usr/bin/install-system.sh", ["./install-system.sh"], 0x7ffc) = 0
100 mkdir("/usr/local/share/bashqueues", 0755) = 0
100 renameat(AT_FDCWD, "/tmp/new", AT_FDCWD, "/usr/local/bin/queue") = 0
100 fchown(3, 0, 0) = 0
TEOF
cat > "$run/lsof.process.trace" <<'LEOF'
COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
bash    100 root txt REG 8,1 1234 55 /usr/bin/bash
bash    100 root cwd DIR 8,1 4096 1 /root
bash    100 root mem REG 8,1 1234 56 /usr/lib64/libc.so.6
LEOF
: > "$run/net.ss.trace"
: > "$run/lsof.net.trace"
python3 "$ROOT/bin/queue-interrogate-compile" compile "$run" --name rootish >/tmp/rootish.compile
net="$QUEUEBASH_ROOT/profiles/interrogation/candidates/rootish.net.env"
file="$QUEUEBASH_ROOT/profiles/interrogation/candidates/rootish.file.env"
grep -q '^NETPROFILE_CAPTURED_USERS=root$' "$net" || { echo '[FAIL] net profile missing captured user' >&2; cat "$net" >&2; exit 1; }
grep -q '^NETPROFILE_CAPTURED_UIDS=0$' "$net" || { echo '[FAIL] net profile missing uid 0' >&2; cat "$net" >&2; exit 1; }
grep -q '^NETPROFILE_PRIVILEGED_CONTEXT=1$' "$net" || { echo '[FAIL] net profile missing privileged flag' >&2; cat "$net" >&2; exit 1; }
grep -q '^FILEPROFILE_ROOT_PROFILE=1$' "$file" || { echo '[FAIL] file profile missing root profile flag' >&2; cat "$file" >&2; exit 1; }
explain="$(python3 "$ROOT/bin/queue-interrogate-compile" explain rootish)"
grep -q 'privilege context:' <<<"$explain" || { echo '[FAIL] explain missing privilege context' >&2; printf '%s\n' "$explain" >&2; exit 1; }
grep -q 'captured_users:        root' <<<"$explain" || { echo '[FAIL] explain missing root user' >&2; printf '%s\n' "$explain" >&2; exit 1; }
grep -q 'privileged_context:    1' <<<"$explain" || { echo '[FAIL] explain missing privileged=1' >&2; printf '%s\n' "$explain" >&2; exit 1; }
grep -q 'root_profile:          1' <<<"$explain" || { echo '[FAIL] explain missing root_profile=1' >&2; printf '%s\n' "$explain" >&2; exit 1; }
grep -q 'privileged_profile_requires_review' <<<"$explain" || { echo '[FAIL] explain missing privileged blocker' >&2; printf '%s\n' "$explain" >&2; exit 1; }
grep -q 'root_profile_requires_review' <<<"$explain" || { echo '[FAIL] explain missing root blocker' >&2; printf '%s\n' "$explain" >&2; exit 1; }
if python3 "$ROOT/bin/queue-interrogate-compile" approve rootish --accept-warnings >/tmp/rootish.approve 2>/tmp/rootish.err; then
  echo '[FAIL] privileged profile approved without --accept-risk' >&2
  exit 1
fi
python3 "$ROOT/bin/queue-interrogate-compile" approve rootish --accept-warnings --accept-risk >/tmp/rootish.approve
approved="$QUEUEBASH_ROOT/profiles/interrogation/approved/rootish.file.env"
grep -q '^FILEPROFILE_SIGNED=1$' "$approved" || { echo '[FAIL] privileged approved profile not signed' >&2; cat "$approved" >&2; exit 1; }

echo '[PASS] interrogation privilege context smoke checks pass'
