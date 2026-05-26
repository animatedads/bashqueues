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

# Legacy flat pending compatibility.
mkdir -p "$QUEUEBASH_ROOT/pending"
cat > "$QUEUEBASH_ROOT/pending/legacy.job" <<'EOF'
JOB_ID=legacy
JOB_NAME=legacy
PRIORITY=5
COMMAND='echo legacy'
STATE=pending
EOF
found=0
while IFS= read -r f; do
  [[ "$f" == "$QUEUEBASH_ROOT/pending/legacy.job" ]] && found=1
done < <(_queue_pending_job_files "$QUEUEBASH_ROOT")
[[ "$found" -eq 1 ]] || fail "legacy flat pending job was not discovered"

echo '[PASS] worker priority bucket smoke checks pass'
