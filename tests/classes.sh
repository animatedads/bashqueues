#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_RUNNER=direct
export QUEUEBASH_GZIP_LOGS=0
source "$repo_root/queuebash.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"
_queue_init
mkdir -p "$QUEUEBASH_ROOT/classes"
fail(){ echo "[FAIL] $1" >&2; queue list >&2 || true; find "$QUEUEBASH_ROOT" -maxdepth 4 -print >&2 || true; exit 1; }
pass(){ echo "[PASS] $1"; }

cat > "$QUEUEBASH_ROOT/classes/SEQ.env" <<'EOF'
CLASS_ALLOW_PARALLEL=0
EOF

queue submit seq1 --class SEQ -- bash -c 'echo one' >/dev/null
queue submit seq2 --class SEQ -- bash -c 'echo two' >/dev/null

first="$(ls "$QUEUEBASH_ROOT/pending"/*.job | sort | head -1)"
second="$(ls "$QUEUEBASH_ROOT/pending"/*.job | sort | tail -1)"
first_id="$(basename "$first" .job)"
mkdir -p "$QUEUEBASH_ROOT/claims/classes/SEQ.$first_id.claim"
echo "$first_id" > "$QUEUEBASH_ROOT/claims/classes/SEQ.$first_id.claim/job_id"
if _queue_class_available "$second"; then
    fail "sequential class allowed second job while first claim existed"
fi
rm -rf "$QUEUEBASH_ROOT/claims/classes/SEQ.$first_id.claim"

queue run --workers 2 >/dev/null || true
done_count="$(grep -l '^JOB_CLASS=SEQ$' "$QUEUEBASH_ROOT"/done/*.job | wc -l | tr -d ' ')"
[[ "$done_count" == "2" ]] || fail "sequential class jobs did not both finish eventually"

cat > "$QUEUEBASH_ROOT/classes/CAMERA.env" <<'EOF'
CLASS_ALLOW_PARALLEL=1
CLASS_EXCLUSIVE_ASSETS="camera_A"
EOF

queue submit cam1 --class CAMERA -- bash -c 'echo cam1' >/dev/null
queue submit cam2 --class CAMERA -- bash -c 'echo cam2' >/dev/null
cam_first="$(ls "$QUEUEBASH_ROOT/pending"/*.job | sort | head -1)"
cam_second="$(ls "$QUEUEBASH_ROOT/pending"/*.job | sort | tail -1)"
cam_id="$(basename "$cam_first" .job)"
mkdir -p "$QUEUEBASH_ROOT/claims/assets/camera_A.exclusive.$cam_id.claim"
echo "$cam_id" > "$QUEUEBASH_ROOT/claims/assets/camera_A.exclusive.$cam_id.claim/job_id"
if _queue_class_available "$cam_second"; then
    fail "exclusive asset allowed competing job"
fi

queue class show SEQ >/dev/null || fail "queue class show failed"
queue claims >/dev/null || fail "queue claims failed"

pass "sequential class blocks parallel class execution"
pass "exclusive asset blocks competing asset users"
pass "class commands work"
echo
echo "bashqueues class tests: OK"
