#!/usr/bin/env bash
# queue_fetch_static.sh — static tests for queue fetch egress policy and output schema
# shellcheck disable=SC1091

set -euo pipefail

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

TMPROOT="$(mktemp -d)"
export QUEUEBASH_ROOT="$TMPROOT"
trap 'rm -rf "$TMPROOT"' EXIT

mkdir -p "$TMPROOT/done" "$TMPROOT/failed" "$TMPROOT/classes" "$TMPROOT/logs"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
# shellcheck source=../queuebash.sh
source "$SCRIPT_DIR/queuebash.sh"

# --- Test 1: fetch unknown job returns exit 1 ---
if _queue_fetch_command --job-id nonexistent-job-id 2>/dev/null; then
    fail "fetch unknown job should fail"
else
    rc=$?
    if [[ "$rc" -eq 1 ]]; then
        pass "fetch unknown job returns exit 1"
    else
        fail "fetch unknown job expected exit 1, got $rc"
    fi
fi

# --- Test 2: fetch done job returns schema queuebash.fetch.v1 ---
JOB_ID2="test-done-job-002"
cat > "$TMPROOT/done/${JOB_ID2}.job" <<'JOBEOF'
JOB_ID=test-done-job-002
JOB_NAME=test-done-job
JOB_CLASS=MOBILE_ANDROID
EXIT_CODE=0
DURATION_SECONDS=10
JOBEOF

cat > "$TMPROOT/classes/MOBILE_ANDROID.env" <<'CLSEOF'
CLASS_EGRESS_ALLOWED_JURISDICTION=GLOBAL
CLASS_EGRESS_REQUIRE_ENCRYPTION=0
CLSEOF

out="$(_queue_fetch_command --job-id "$JOB_ID2" --json 2>/dev/null)"
if echo "$out" | grep -q '"schema":"queuebash.fetch.v1"'; then
    pass "fetch done job returns schema queuebash.fetch.v1"
else
    fail "fetch done job did not return queuebash.fetch.v1 schema; got: $out"
fi

# --- Test 3: egress audit log is written on allowed fetch ---
if [[ -f "$TMPROOT/logs/egress-audit.jsonl" ]]; then
    if grep -q '"decision":"allow"' "$TMPROOT/logs/egress-audit.jsonl"; then
        pass "egress audit log contains allow decision"
    else
        fail "egress audit log missing allow decision"
    fi
else
    fail "egress audit log not written"
fi

# --- Test 4: fetch with CLASS_EGRESS_ALLOWED_JURISDICTION=NONE returns exit 3 ---
JOB_ID="test-none-egress-001"
cat > "$TMPROOT/done/${JOB_ID}.job" <<'JOBEOF'
JOB_ID=test-none-egress-001
JOB_NAME=test-none-job
JOB_CLASS=MOBILE_LOCAL_ONLY
EXIT_CODE=0
DURATION_SECONDS=5
JOBEOF

cat > "$TMPROOT/classes/MOBILE_LOCAL_ONLY.env" <<'CLSEOF'
CLASS_EGRESS_ALLOWED_JURISDICTION=NONE
CLASS_EGRESS_REQUIRE_ENCRYPTION=1
CLSEOF

if _queue_fetch_command --job-id "$JOB_ID" 2>/dev/null; then
    fail "fetch with JURISDICTION=NONE should fail"
else
    rc=$?
    if [[ "$rc" -eq 3 ]]; then
        pass "fetch with CLASS_EGRESS_ALLOWED_JURISDICTION=NONE returns exit 3"
    else
        fail "fetch with JURISDICTION=NONE expected exit 3, got $rc"
    fi
fi

# --- Test 5: egress audit log deny entry written on NONE jurisdiction ---
if grep -q '"decision":"deny"' "$TMPROOT/logs/egress-audit.jsonl"; then
    pass "egress audit log contains deny decision"
else
    fail "egress audit log missing deny decision"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] || exit 1
