#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_RUNNER=direct
export QUEUEBASH_GZIP_LOGS=0
export QUEUEBASH_PLUGIN_SOURCE_DIR="$repo_root/assets.d"
export QUEUEBASH_CLASS_SOURCE_DIR="$repo_root/classes"

source "$repo_root/queuebash.sh"
source "$repo_root/queuemgr.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"
_queue_init

fail() {
    echo "[FAIL] $1" >&2
    exit 1
}

pass(){ echo "[PASS] $1"; }

facilities="$(_queue_mgr_list_facilities_compact)"
grep -q 'path:exists' <<< "$facilities" || fail "wizard facility list missing path:exists"

[[ "$(_queue_mgr_facility_family path:exists)" == "path" ]] || fail "facility family parse failed"
[[ "$(_queue_mgr_facility_check path:exists)" == "exists" ]] || fail "facility check parse failed"

tmp_defaults="$(mktemp)"
cat > "$tmp_defaults" <<'EOF'
CLASS_DEFAULT_RUNNER=direct
CLASS_DEFAULT_TIMEOUT=10s
EOF

preview="$(_queue_mgr_wizard_render_preview TESTWIZ 1 0 "$tmp_defaults" \
  'queue_class_shared_asset path exists "/tmp"' \
  'queue_class_exclusive_claim test:slot')"

grep -q '^CLASS_ALLOW_PARALLEL=1$' <<< "$preview" || fail "preview missing allow parallel"
grep -q '^CLASS_DEFAULT_TIMEOUT=10s$' <<< "$preview" || fail "preview missing defaults"
grep -q 'queue_class_shared_asset path exists "/tmp"' <<< "$preview" || fail "preview missing shared asset"
grep -q 'queue_class_exclusive_claim test:slot' <<< "$preview" || fail "preview missing claim"

mkdir -p "$QUEUEBASH_ROOT/classes"
printf '%s\n' "$preview" > "$QUEUEBASH_ROOT/classes/TESTWIZ.env"
queue classes validate TESTWIZ >/dev/null || fail "wizard preview class did not validate"

pass "wizard can list helper-published facilities"
pass "wizard renders record-format class preview"
pass "wizard-generated class validates"

echo
echo "bashqueues class wizard helper tests: OK"
