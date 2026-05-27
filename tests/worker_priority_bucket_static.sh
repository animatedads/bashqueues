#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
q="$ROOT/queuebash.sh"
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -q '^QUEUEBASH_VERSION="0.17.97"' "$q" || fail "version is not 0.17.95"
grep -q '_queue_pending_bucket_key()' "$q" || fail "missing pending bucket key helper"
grep -q '_queue_pending_path_for_priority()' "$q" || fail "missing pending path helper"
grep -q '_queue_pending_job_files()' "$q" || fail "missing pending tree iterator"
grep -q '_queue_rebucket_pending_job()' "$q" || fail "missing pending rebucket helper"
grep -q '_queue_move_to_pending_bucket()' "$q" || fail "missing pending move helper"
grep -q 'job="$(.*_queue_pending_path_for_priority' "$q" || fail "submit does not use pending priority bucket helper"
grep -q '_queue_rebucket_pending_job "$f" "$new_priority"' "$q" || fail "priority command does not rebucket pending jobs"
! test -e "$ROOT/assets.d/net_usage.sh" || fail "assets.d/net_usage.sh must remain absent"

echo '[PASS] worker priority bucket static checks pass'
