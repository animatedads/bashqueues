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
export QUEUEBASH_ENV_SOURCE_DIR="$ROOT/envs.d"
export QUEUEBASH_POLICY_SOURCE_DIR="$ROOT/policies.d"
export QUEUEBASH_REPORTER_PLUGIN_SOURCE_DIR="$ROOT/reporters.d"
source "$ROOT/queuebash.sh"
fail(){ echo "[FAIL] $*" >&2; exit 1; }

queue env list >/tmp/env_list.$$
grep -q '^test[[:space:]]' /tmp/env_list.$$ || fail "test profile not listed"
grep -q '^live[[:space:]]' /tmp/env_list.$$ || fail "live profile not listed"
rm -f /tmp/env_list.$$
queue env validate test >/dev/null || fail "test profile validation failed"
queue env show live --json | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["name"]=="live" and d["secret_scope"]=="live", d' || fail "live JSON wrong"

# Direct asset checks through the same preflight helper surface used by workers.
out="$(_queue_asset_implied_preflight_args env:profile_required env profile_required test || true)"
grep -q 'asset_check_blocked' <<<"$out" || fail "profile_required should block without CLASS_EXEC_ENV"
out="$(CLASS_EXEC_ENV=test _queue_asset_implied_preflight_args env:profile_required env profile_required test)"
grep -q 'asset_check_ok' <<<"$out" || fail "profile_required test did not pass with CLASS_EXEC_ENV"
out="$(CLASS_EXEC_ENV=test _queue_asset_implied_preflight_args env:secret_scope env secret_scope test profile=test)"
grep -q 'asset_check_ok' <<<"$out" || fail "secret_scope test did not pass"
if CLASS_EXEC_ENV=test _queue_asset_implied_preflight_args env:secret_scope env secret_scope live profile=test >/dev/null 2>&1; then
    fail "secret_scope live unexpectedly passed for test profile"
fi

qid_line="$(queue submit env-smoke --class ENV_TEST -- bash -c 'echo env-smoke')"
qid="$(awk '{print $2}' <<<"$qid_line")"
job_file="$(find "$QUEUEBASH_ROOT/pending" -name "$qid.job" -print -quit)"
[[ -f "$job_file" ]] || fail "submitted job file not found"
grep -q '^EXEC_ENV=test$' "$job_file" || fail "job file not stamped with EXEC_ENV=test"
_queue_class_available "$job_file" >/tmp/env_run.$$ 2>&1 || { cat /tmp/env_run.$$ >&2; fail "class/env preflight failed"; }
rm -f /tmp/env_run.$$

echo "[PASS] execution environment smoke checks pass"
