#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"
mkdir -p "$QUEUEBASH_ROOT/profiles/interrogation/campaigns/camp/run-001" "$QUEUEBASH_ROOT/profiles/interrogation/campaigns/camp/run-002"
cat > "$QUEUEBASH_ROOT/profiles/interrogation/campaigns/camp/campaign.env" <<'EOF'
CAMPAIGN_ID=camp
CAMPAIGN_NAME=test
EOF
cat > "$QUEUEBASH_ROOT/profiles/interrogation/campaigns/camp/run-001/profile.env" <<'EOF'
PROFILE_RUN_ID=run-001
EOF
cat > "$QUEUEBASH_ROOT/profiles/interrogation/campaigns/camp/run-001/syscalls.raw.trace" <<'EOF'
100 execve("/usr/bin/rexx", ["rexx"], 0x7ffc) = 0
100 openat(AT_FDCWD, "/tmp/counter.txt", O_RDWR|O_CREAT) = 3
100 close(3) = 0
EOF
cat > "$QUEUEBASH_ROOT/profiles/interrogation/campaigns/camp/run-001/net.ss.trace" <<'EOF'
EOF
cat > "$QUEUEBASH_ROOT/profiles/interrogation/campaigns/camp/run-001/lsof.process.trace" <<'EOF'
COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
rexx 100 hc3 3u REG 8,1 10 10 /tmp/counter.txt
EOF
cat > "$QUEUEBASH_ROOT/profiles/interrogation/campaigns/camp/run-002/profile.env" <<'EOF'
PROFILE_RUN_ID=run-002
EOF
cat > "$QUEUEBASH_ROOT/profiles/interrogation/campaigns/camp/run-002/syscalls.raw.trace" <<'EOF'
200 execve("/usr/bin/rexx", ["rexx"], 0x7ffc) = 0
200 openat(AT_FDCWD, "/tmp/counter.txt", O_RDWR|O_CREAT) = 3
201 execve("/usr/bin/wget", ["wget"], 0x7ffc) = 0
201 socket(AF_INET, SOCK_STREAM, IPPROTO_TCP) = 4
201 connect(4, {sa_family=AF_INET, sin_port=htons(80)}, 16) = 0
202 execve("/usr/bin/rm", ["rm", "-rf", "/tmp/bashqueues_test_dir"], 0x7ffc) = 0
202 unlinkat(AT_FDCWD, "/tmp/bashqueues_test_dir/index.html", 0) = 0
EOF
cat > "$QUEUEBASH_ROOT/profiles/interrogation/campaigns/camp/run-002/net.ss.trace" <<'EOF'
tcp ESTAB 0 0 10.0.0.1:43210 142.250.187.4:80 users:(("wget",pid=201,fd=4))
EOF
cat > "$QUEUEBASH_ROOT/profiles/interrogation/campaigns/camp/run-002/lsof.process.trace" <<'EOF'
COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
rexx 200 hc3 3u REG 8,1 10 10 /tmp/counter.txt
wget 201 hc3 txt REG 8,1 123 20 /usr/bin/wget
wget 201 hc3 4u IPv4 12345 0t0 TCP 10.0.0.1:43210->142.250.187.4:80 (ESTABLISHED)
rm   202 hc3 cwd DIR 8,1 40 30 /tmp/bashqueues_test_dir
EOF
python3 "$ROOT/bin/queue-interrogate-compile" diff-runs "$QUEUEBASH_ROOT/profiles/interrogation/campaigns/camp" --json > "$tmp/diff.json"
python3 - "$tmp/diff.json" <<'PY'
import json, sys
d=json.load(open(sys.argv[1]))
assert d["drift_detected"], d
run=d["runs"][0]
assert "socket" in run["new_syscalls"], run
assert "80" in run["new_remote_ports"], run
PY
python3 "$ROOT/bin/queue-interrogate-compile" merge "$QUEUEBASH_ROOT/profiles/interrogation/campaigns/camp" --name naughty_rexx --json > "$tmp/merge.json"
grep -q 'socket' "$QUEUEBASH_ROOT/profiles/interrogation/candidates/naughty_rexx.seccomp.env"
grep -q '80' "$QUEUEBASH_ROOT/profiles/interrogation/candidates/naughty_rexx.net.env"
[[ -f "$QUEUEBASH_ROOT/profiles/interrogation/campaigns/camp/merged/candidate.seccomp.env" ]]
echo '[PASS] interrogation campaign smoke checks pass'
