#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/qroot"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_PLUGIN_SOURCE_DIR="$ROOT/assets.d"
export QUEUEBASH_CAP_PLUGIN_SOURCE_DIR="$ROOT/caps.d"
export QUEUEBASH_CLASS_SOURCE_DIR="$ROOT/classes"
export QUEUEBASH_POLICY_SOURCE_DIR="$ROOT/policies.d"
export QUEUEBASH_REPORTER_PLUGIN_SOURCE_DIR="$ROOT/reporters.d"
source "$ROOT/queuebash.sh"
fail(){ echo "[FAIL] $*" >&2; exit 1; }

queue submit low --priority 1 -- bash -c 'echo low' >/dev/null
queue submit high --priority 99 -- bash -c 'echo high' >/dev/null
queue submit mid --priority 10 -- bash -c 'echo mid' >/dev/null

compgen -G "$QUEUEBASH_ROOT/pending/p*/prompt_placeholder_never" >/dev/null 2>&1 || true
bucket_count="$(find "$QUEUEBASH_ROOT/pending" -mindepth 1 -maxdepth 1 -type d -name 'p*' | wc -l | tr -d ' ')"
[[ "$bucket_count" -ge 3 ]] || fail "expected priority bucket directories, got $bucket_count"

first="$(_queue_next_job "$(date +%s)")"
[[ "$(grep -E '^JOB_NAME=' "$first" | cut -d= -f2-)" == "high" ]] || fail "highest priority job not selected first: $first"

queue priority low 150 >/dev/null
rebucketed="$(_queue_next_job "$(date +%s)")"
[[ "$(grep -E '^JOB_NAME=' "$rebucketed" | cut -d= -f2-)" == "low" ]] || fail "priority change did not rebucket low to first: $rebucketed"

# Legacy flat pending compatibility: old pending/*.job files are normalised
# into priority buckets before ordered scanning, so they do not remain as a
# permanent mixed-format root-pending file.
mkdir -p "$QUEUEBASH_ROOT/pending"
cat > "$QUEUEBASH_ROOT/pending/legacy.job" <<'EOF'
JOB_ID=legacy
JOB_NAME=legacy
PRIORITY=5
COMMAND='echo legacy'
STATE=pending
EOF
found=0
legacy_path=""
while IFS= read -r f; do
  case "$f" in
    "$QUEUEBASH_ROOT/pending"/p*/legacy.job) found=1; legacy_path="$f" ;;
  esac
done < <(_queue_pending_job_files "$QUEUEBASH_ROOT")
[[ "$found" -eq 1 ]] || fail "legacy flat pending job was not normalised into a priority bucket"
[[ ! -e "$QUEUEBASH_ROOT/pending/legacy.job" ]] || fail "legacy flat pending job remained in root pending directory"
[[ "$legacy_path" == "$QUEUEBASH_ROOT/pending/p0999999995/legacy.job" ]] || fail "legacy pending job moved to wrong bucket: $legacy_path"

# Rebucketing a pending job should remove the old empty bucket.
queue submit cleanup --priority 20 -- bash -c 'echo cleanup' >/dev/null
cleanup_id="$(queue list --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print([j["qid"] for j in d["jobs"] if j["name"]=="cleanup"][0])')"
[[ -d "$QUEUEBASH_ROOT/pending/p0999999980" ]] || fail "cleanup job was not submitted into priority 20 bucket"
queue priority "$cleanup_id" 21 >/dev/null
[[ -d "$QUEUEBASH_ROOT/pending/p0999999979" ]] || fail "cleanup job was not rebucketed to priority 21"
[[ ! -d "$QUEUEBASH_ROOT/pending/p0999999980" ]] || fail "old empty priority bucket was not removed"

echo '[PASS] worker priority bucket smoke checks pass'
