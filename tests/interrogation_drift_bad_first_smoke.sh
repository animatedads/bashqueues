#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"
camp="$QUEUEBASH_ROOT/profiles/interrogation/campaigns/badfirst"
mkdir -p "$camp/run-001" "$camp/run-002"
cat > "$camp/campaign.env" <<'EOC'
CAMPAIGN_ID=badfirst
CAMPAIGN_NAME=badfirst
EOC
cat > "$camp/run-001/profile.env" <<'EOR'
PROFILE_RUN_ID=run-001
EOR
cat > "$camp/run-001/syscalls.raw.trace" <<'EOR'
100 execve("/usr/bin/rexx", ["rexx"], 0x7ffc) = 0
101 execve("/usr/bin/wget", ["wget"], 0x7ffc) = 0
101 socket(AF_INET, SOCK_STREAM, IPPROTO_TCP) = 4
101 connect(4, {sa_family=AF_INET, sin_port=htons(80)}, 16) = 0
102 execve("/usr/bin/rm", ["rm", "-rf", "/tmp/bashqueues_test_dir"], 0x7ffc) = 0
102 unlinkat(AT_FDCWD, "/tmp/bashqueues_test_dir/index.html", 0) = 0
EOR
cat > "$camp/run-001/net.ss.trace" <<'EOR'
tcp ESTAB 0 0 10.0.0.1:43210 142.250.187.4:80 users:(("wget",pid=101,fd=4))
EOR
cat > "$camp/run-001/lsof.process.trace" <<'EOR'
COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
rexx 100 hc3 3u REG 8,1 10 10 /tmp/counter.txt
wget 101 hc3 txt REG 8,1 123 20 /usr/bin/wget
wget 101 hc3 4u IPv4 12345 0t0 TCP 10.0.0.1:43210->142.250.187.4:80 (ESTABLISHED)
rm   102 hc3 cwd DIR 8,1 40 30 /tmp/bashqueues_test_dir
EOR
cat > "$camp/run-002/profile.env" <<'EOR'
PROFILE_RUN_ID=run-002
EOR
cat > "$camp/run-002/syscalls.raw.trace" <<'EOR'
200 execve("/usr/bin/rexx", ["rexx"], 0x7ffc) = 0
200 openat(AT_FDCWD, "/tmp/counter.txt", O_RDWR|O_CREAT) = 3
200 close(3) = 0
EOR
: > "$camp/run-002/net.ss.trace"
cat > "$camp/run-002/lsof.process.trace" <<'EOR'
COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
rexx 200 hc3 3u REG 8,1 10 10 /tmp/counter.txt
EOR
python3 "$ROOT/bin/queue-interrogate-compile" diff-runs "$camp" --json > "$tmp/diff.json"
python3 - "$tmp/diff.json" <<'PY'
import json, sys
d=json.load(open(sys.argv[1]))
assert d["drift_detected"], d
run=d["runs"][0]
assert "socket" in run["missing_syscalls"], run
assert "80" in run["missing_remote_ports"], run
assert run["changed_from_previous"]["missing_remote_ports"] == ["80"], run
PY
grep -q 'missing_syscalls' "$camp/drift.report.json"
echo '[PASS] interrogation bad-first drift smoke checks pass'
