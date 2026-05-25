#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(mktemp -d)"
POL="$(mktemp -d)"
trap 'rm -rf "$ROOT" "$POL"' EXIT
mkdir -p "$POL/class-statement"
cat > "$POL/class-statement/default.env" <<'POLICY'
QUEUEBASH_POLICY_KIND=class-statement
QUEUEBASH_POLICY_NAME=default
CLASS_POLICY_USER_SANDBOX_POLICIES="off network-none restrict-egress strict queue-default"
CLASS_POLICY_USER_SECCOMP_POLICIES="off docker-default strict queue-default"
CLASS_POLICY_EXCEPTION_FLAGS_REQUIRE="authorisation"
CLASS_POLICY_WEAK_POLICY_REQUIRE="authorisation"
CLASS_POLICY_USER_WEBADMINS_ALLOW_ADD_PORTS="80 1080 8080"
POLICY
export QUEUEBASH_ROOT="$ROOT"
export QUEUEBASH_POLICY_SOURCE_DIR="$POL"
export QUEUEBASH_CLASS_POLICY_STATEMENT=default
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
# webadmins has standing policy permission for port 8080 and should not need a code.
source ./queuebash.sh
QUEUEBASH_SELECTED_USER=webadmins queue submit webjob --add-port 8080 -- true >/dev/null
# dba does not have the grant and must still be blocked by the authorisation requirement.
if QUEUEBASH_SELECTED_USER=dba queue submit dbajob --add-port 8080 -- true >/tmp/bq_grant_out.$$ 2>&1; then
    echo "[FAIL] dba unexpectedly bypassed the port authorisation requirement" >&2
    exit 1
fi
grep -Eq 'requires --authorisation|requires --reason TEXT or --authorisation CODE|requires --authorisation CODE' /tmp/bq_grant_out.$$
rm -f /tmp/bq_grant_out.$$
echo '[PASS] per-user port grants allow webadmins but not dba'
