#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh >/dev/null

cand="$QUEUEBASH_ROOT/profiles/interrogation/candidates"
mkdir -p "$cand"
cat > "$cand/good.seccomp.env" <<'EOF'
SECPROFILE_NAME=good
SECPROFILE_STATUS=candidate
SECPROFILE_SHOULD_BE_SIGNED=1
SECPROFILE_SIGNED=0
SECPROFILE_SCOPE=pid_tree
SECPROFILE_ALLOWED_SYSCALLS=read,write,openat,close,exit_group
SECPROFILE_DEFAULT_ACTION=kill
EOF
cat > "$cand/good.net.env" <<'EOF'
NETPROFILE_NAME=good
NETPROFILE_STATUS=candidate
NETPROFILE_SHOULD_BE_SIGNED=1
NETPROFILE_SIGNED=0
NETPROFILE_SCOPE=pid_tree
NETPROFILE_GLOBAL_SS_USED=0
NETPROFILE_ALLOWED_PROTOCOLS=
NETPROFILE_ALLOWED_REMOTE_PORTS=
NETPROFILE_ALLOWED_REMOTE_HOSTS=
NETPROFILE_DENY_LISTEN=0
NETPROFILE_CONTEXT_REMOTE_PORTS_IGNORED=443,993
NETPROFILE_CONTEXT_REMOTE_HOSTS_IGNORED=example.invalid
NETPROFILE_WARNINGS=global_network_context_ignored
EOF
cat > "$cand/good.file.env" <<'EOF'
FILEPROFILE_NAME=good
FILEPROFILE_STATUS=candidate
FILEPROFILE_SHOULD_BE_SIGNED=1
FILEPROFILE_SIGNED=0
FILEPROFILE_SCOPE=pid_tree
FILEPROFILE_ALLOWED_READ_PREFIXES=/usr/bin,/usr/lib64
FILEPROFILE_ALLOW_DELETED_FILES=0
FILEPROFILE_ALLOWED_UNIX_SOCKETS=
FILEPROFILE_WARNINGS=
EOF

explain="$(queue profile interrogate explain good)"
grep -q 'decision: approval_requires_accept_warnings' <<<"$explain" || fail "explain did not require warning acknowledgement"
grep -q 'global_network_context_ignored' <<<"$explain" || fail "explain omitted warning"

if queue profile interrogate approve good >/tmp/approve.out 2>/tmp/approve.err; then
  fail "approve unexpectedly succeeded without --accept-warnings"
fi
queue profile interrogate approve good --accept-warnings --signing-key self:test-key >/tmp/approve.out

grep -q 'signed_by=self:test-key' /tmp/approve.out || fail "approve did not report signing key"
grep -q 'SECPROFILE_SIGNED=1' "$QUEUEBASH_ROOT/profiles/interrogation/approved/good.seccomp.env" || fail "seccomp not signed"
grep -q 'SECPROFILE_SIGNED_BY=self:test-key' "$QUEUEBASH_ROOT/profiles/interrogation/approved/good.seccomp.env" || fail "seccomp signed_by missing"

cat > "$cand/risky.seccomp.env" <<'EOF'
SECPROFILE_NAME=risky
SECPROFILE_STATUS=candidate
SECPROFILE_SHOULD_BE_SIGNED=1
SECPROFILE_SIGNED=0
SECPROFILE_SCOPE=pid_tree
SECPROFILE_ALLOWED_SYSCALLS=read,write,unlink,unlinkat,mkdir,execve,exit_group
SECPROFILE_DEFAULT_ACTION=kill
EOF
cat > "$cand/risky.net.env" <<'EOF'
NETPROFILE_NAME=risky
NETPROFILE_STATUS=candidate
NETPROFILE_SHOULD_BE_SIGNED=1
NETPROFILE_SIGNED=0
NETPROFILE_SCOPE=pid_tree
NETPROFILE_GLOBAL_SS_USED=0
NETPROFILE_ALLOWED_PROTOCOLS=tcp
NETPROFILE_ALLOWED_REMOTE_PORTS=80
NETPROFILE_ALLOWED_REMOTE_HOSTS=142.251.151.119
NETPROFILE_DENY_LISTEN=0
NETPROFILE_WARNINGS=
EOF
cat > "$cand/risky.file.env" <<'EOF'
FILEPROFILE_NAME=risky
FILEPROFILE_STATUS=candidate
FILEPROFILE_SHOULD_BE_SIGNED=1
FILEPROFILE_SIGNED=0
FILEPROFILE_SCOPE=pid_tree
FILEPROFILE_ALLOWED_READ_PREFIXES=/home,/tmp,/usr/bin
FILEPROFILE_ALLOW_DELETED_FILES=0
FILEPROFILE_ALLOWED_UNIX_SOCKETS=
FILEPROFILE_WARNINGS=broad_home_prefix,broad_tmp_prefix
EOF
rexplain="$(queue profile interrogate explain risky)"
grep -q 'decision: approval_requires_accept_risk' <<<"$rexplain" || fail "risky explain did not require risk acceptance"
grep -q 'network_egress_requires_review' <<<"$rexplain" || fail "risky explain omitted network blocker"
if queue profile interrogate approve risky --accept-warnings >/tmp/risky.out 2>/tmp/risky.err; then
  fail "risky approve unexpectedly succeeded without --accept-risk"
fi
queue profile interrogate approve risky --accept-warnings --accept-risk >/tmp/risky.out
[[ -f "$QUEUEBASH_ROOT/profiles/interrogation/approved/risky.net.env" ]] || fail "risky accepted profile not approved with explicit risk"

echo '[PASS] interrogation explain/approve gate smoke checks pass'
