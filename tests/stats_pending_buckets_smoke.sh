#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/qroot"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source "$ROOT/queuebash.sh"

fail(){ echo "[FAIL] $*" >&2; exit 1; }

queue submit bucketed-one --priority 20 -- bash -c 'echo bucketed-one' >/dev/null
queue submit bucketed-two --priority 5 -- bash -c 'echo bucketed-two' >/dev/null

# Simulate an old pre-0.17.90 flat pending job left in pending/*.job.
mkdir -p "$QUEUEBASH_ROOT/pending" "$QUEUEBASH_ROOT/policy_blocked"
cat > "$QUEUEBASH_ROOT/pending/legacy_flat.job" <<'JOB'
JOB_ID=legacy_flat
JOB_NAME=legacy-flat
PRIORITY=15
SUBMITTED_AT=2026-05-26T16:00:00+01:00
COMMAND=( echo legacy-flat )
JOB

# Legacy policy_blocked files may still exist on disk, but queue stats should
# no longer expose a separate policy_blocked line or include it in the total.
cat > "$QUEUEBASH_ROOT/policy_blocked/legacy_policy.job" <<'JOB'
JOB_ID=legacy_policy
JOB_NAME=legacy-policy
PRIORITY=10
SUBMITTED_AT=2026-05-26T16:00:00+01:00
COMMAND=( echo legacy-policy )
JOB

out="$(queue stats)"
printf '%s\n' "$out"

grep -Eq '^pending:[[:space:]]+3$' <<<"$out" || fail "pending count should include bucketed and legacy flat pending jobs"
! grep -Eq '^policy_blocked:' <<<"$out" || fail "legacy policy_blocked line should not be shown"
grep -Eq '^total:[[:space:]]+3$' <<<"$out" || fail "total should exclude legacy policy_blocked count"

# queue stats normalises legacy flat pending files through the bucket-aware helper.
[[ ! -e "$QUEUEBASH_ROOT/pending/legacy_flat.job" ]] || fail "legacy flat pending job was not normalised into a bucket"
find "$QUEUEBASH_ROOT/pending" -mindepth 2 -maxdepth 2 -name 'legacy_flat.job' | grep -q . || fail "legacy flat pending job not found in priority bucket"

echo "[PASS] stats pending bucket smoke checks pass"
