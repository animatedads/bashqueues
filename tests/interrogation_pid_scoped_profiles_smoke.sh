#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"
run="$QUEUEBASH_ROOT/profiles/interrogation/runs/pidscoped"
mkdir -p "$run"
cat > "$run/profile.env" <<'EOP'
PROFILE_RUN_ID=pidscoped
EOP
cat > "$run/syscalls.raw.trace" <<'EOT'
100 execve("/usr/bin/rexx", ["rexx"], 0x7ffc) = 0
100 openat(AT_FDCWD, "/home/hc3/test.rex", O_RDONLY) = 3
100 wait4(101, [{WIFEXITED(s) && WEXITSTATUS(s) == 0}], 0, NULL) = 101
100 close(3) = 0
EOT
# Global machine-wide traffic must remain context only; this mimics browser/mail/DHCP noise.
cat > "$run/net.ss.trace" <<'EOT'
tcp ESTAB 0 0 10.0.0.1:44550 142.250.117.95:443 users:(("firefox",pid=999,fd=44))
tcp ESTAB 0 0 10.0.0.1:50000 185.42.170.200:993 users:(("mail",pid=998,fd=9))
udp ESTAB 0 0 0.0.0.0:68 192.168.188.1:67 users:(("dhclient",pid=997,fd=6))
EOT
cat > "$run/lsof.net.trace" <<'EOT'
firefox 999 hc3 44u IPv4 12345 0t0 TCP 10.0.0.1:44550->142.250.117.95:443 (ESTABLISHED)
mail    998 hc3 9u  IPv4 12346 0t0 TCP 10.0.0.1:50000->185.42.170.200:993 (ESTABLISHED)
EOT
# PID scoped lsof contains no network sockets for the profiled process.
cat > "$run/lsof.process.trace" <<'EOT'
COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
rexx    100 hc3 txt REG 8,1 1234 55 /usr/bin/rexx
rexx    100 hc3 mem REG 8,1 1234 56 /usr/lib64/libc.so.6
rexx    100 hc3 3r  REG 8,1 1234 57 /home/hc3/test.rex
EOT
python3 "$ROOT/bin/queue-interrogate-compile" compile "$run" --name pidscoped --json > "$tmp/compile.json"
sec="$QUEUEBASH_ROOT/profiles/interrogation/candidates/pidscoped.seccomp.env"
net="$QUEUEBASH_ROOT/profiles/interrogation/candidates/pidscoped.net.env"
file="$QUEUEBASH_ROOT/profiles/interrogation/candidates/pidscoped.file.env"
grep -q 'SECPROFILE_SCOPE=pid_tree' "$sec"
if grep -q 'WEXITSTATUS' "$sec"; then
  echo '[FAIL] non-syscall token WEXITSTATUS leaked into seccomp candidate' >&2
  exit 1
fi
grep -q 'wait4' "$sec"
grep -q 'NETPROFILE_SCOPE=pid_tree' "$net"
grep -q 'NETPROFILE_GLOBAL_SS_USED=0' "$net"
grep -q '^NETPROFILE_ALLOWED_REMOTE_PORTS=$' "$net"
grep -q 'NETPROFILE_CONTEXT_REMOTE_PORTS_IGNORED=67,443,993' "$net"
grep -q 'global_network_context_ignored' "$net"
grep -q 'FILEPROFILE_SCOPE=pid_tree' "$file"
grep -q 'FILEPROFILE_ALLOW_DELETED_FILES=0' "$file"
echo '[PASS] interrogation PID-scoped profile smoke checks pass'
