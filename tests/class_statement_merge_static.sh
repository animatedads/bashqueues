#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/shared/class-statement" "$tmp/root/classes"

cat > "$tmp/shared/class-statement/default.env" <<'EOF'
QUEUEBASH_POLICY_KIND=class-statement
QUEUEBASH_POLICY_NAME=default
CLASS_POLICY_USER_SANDBOX_POLICIES="off strict queue-default"
CLASS_POLICY_USER_SECCOMP_POLICIES="off strict queue-default"
CLASS_POLICY_EXCEPTION_FLAGS_REQUIRE="reason-or-authorisation"
CLASS_POLICY_WEAK_POLICY_REQUIRE="reason-or-authorisation"
CLASS_POLICY_SANDBOX_REASON_REQUIRED="off"
CLASS_POLICY_SECCOMP_REASON_REQUIRED="off"
CLASS_POLICY_AUTHORISATION_SIGNATURE_REQUIRED="if-trusted-key"
EOF

cat > "$tmp/shared/class-statement/policyblock-test.env" <<'EOF'
QUEUEBASH_POLICY_KIND=class-statement
QUEUEBASH_POLICY_NAME=policyblock-test
CLASS_POLICY_BLOCK_CLASS_NAMES="cron_3dfa21b83bfa"
CLASS_POLICY_BLOCK_CLASS_REQUIRE="authorisation"
EOF

cat > "$tmp/root/classes/cron_3dfa21b83bfa.env" <<'EOF'
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
CLASS_DEFAULT_RUNNER=direct
EOF

QUEUEBASH_ALLOW_NONINTERACTIVE=1 \
QUEUEBASH_ROOT="$tmp/root" \
QUEUEBASH_SHARED_POLICY_ROOT="$tmp/shared" \
bash -lc '
    set -euo pipefail
    source ./queuebash.sh

    _queue_security_policy_statement_source
    [[ " $CLASS_POLICY_BLOCK_CLASS_NAMES " == *" cron_3dfa21b83bfa "* ]]
    [[ "$CLASS_POLICY_BLOCK_CLASS_REQUIRE" == "authorisation" ]]
    [[ " $CLASS_POLICY_USER_SANDBOX_POLICIES " == *" off "* ]]
    [[ " $CLASS_POLICY_USER_SANDBOX_POLICIES " == *" strict "* ]]

    out=$(queue submit blockedcron --class cron_3dfa21b83bfa -- bash -lc "echo should-not-run")
    qid=$(printf "%s\n" "$out" | awk "{print \$2}")
    queue run >/dev/null 2>&1 || true

    [[ -f "$QUEUEBASH_ROOT/pol_block/$qid.job" ]]
    if [[ -f "$QUEUEBASH_ROOT/logs/$qid.log" ]] && grep -q "should-not-run" "$QUEUEBASH_ROOT/logs/$qid.log"; then
        echo "blocked job payload appears to have run" >&2
        exit 1
    fi

    explain_out="$(queue policy explain)"
    grep -q "policyblock-test" <<< "$explain_out"
    grep -q "CLASS_POLICY_BLOCK_CLASS_NAMES=cron_3dfa21b83bfa" <<< "$explain_out"
'

echo "OK: all class-statement policy files are merged into the execution gate"
