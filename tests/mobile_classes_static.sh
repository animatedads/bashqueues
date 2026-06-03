#!/usr/bin/env bash
# mobile_classes_static.sh — static tests for MOBILE_* class file contents

set -euo pipefail

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLASSES_DIR="$REPO_DIR/classes"

check_var() {
    local file="$1" key="$2" expected="$3"
    local val
    val="$(grep "^${key}=" "$file" 2>/dev/null | tail -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null || true)"
    if [[ "$val" == "$expected" ]]; then
        pass "${file##*/}: ${key}=${expected}"
    else
        fail "${file##*/}: expected ${key}=${expected}, got ${key}=${val:-<unset>}"
    fi
}

# CLASS files must exist
for cls in MOBILE_ANDROID MOBILE_IOS MOBILE_LOCAL_ONLY; do
    f="$CLASSES_DIR/${cls}.env"
    if [[ -f "$f" ]]; then
        pass "${cls}.env exists"
    else
        fail "${cls}.env does not exist"
    fi
done

# CLASS_MAX_CONCURRENT=1 for all three
for cls in MOBILE_ANDROID MOBILE_IOS MOBILE_LOCAL_ONLY; do
    check_var "$CLASSES_DIR/${cls}.env" CLASS_MAX_CONCURRENT 1
done

# CLASS_EGRESS_ALLOWED_JURISDICTION=NONE only in MOBILE_LOCAL_ONLY
check_var "$CLASSES_DIR/MOBILE_LOCAL_ONLY.env" CLASS_EGRESS_ALLOWED_JURISDICTION NONE

# MOBILE_ANDROID and MOBILE_IOS allow GLOBAL jurisdiction
check_var "$CLASSES_DIR/MOBILE_ANDROID.env" CLASS_EGRESS_ALLOWED_JURISDICTION GLOBAL
check_var "$CLASSES_DIR/MOBILE_IOS.env" CLASS_EGRESS_ALLOWED_JURISDICTION GLOBAL

# CLASS_DEFAULT_CPU_LIMIT=10 for MOBILE_ANDROID and MOBILE_IOS
check_var "$CLASSES_DIR/MOBILE_ANDROID.env" CLASS_DEFAULT_CPU_LIMIT 10
check_var "$CLASSES_DIR/MOBILE_IOS.env" CLASS_DEFAULT_CPU_LIMIT 10

# MOBILE_LOCAL_ONLY has stricter CPU limit
check_var "$CLASSES_DIR/MOBILE_LOCAL_ONLY.env" CLASS_DEFAULT_CPU_LIMIT 5

# MOBILE_LOCAL_ONLY has CLASS_NO_NETWORK=1
check_var "$CLASSES_DIR/MOBILE_LOCAL_ONLY.env" CLASS_NO_NETWORK 1

# MOBILE_ANDROID and MOBILE_IOS require encryption
check_var "$CLASSES_DIR/MOBILE_ANDROID.env" CLASS_EGRESS_REQUIRE_ENCRYPTION 1
check_var "$CLASSES_DIR/MOBILE_IOS.env" CLASS_EGRESS_REQUIRE_ENCRYPTION 1

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] || exit 1
