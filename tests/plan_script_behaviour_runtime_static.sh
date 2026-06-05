#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT/bin/queue-plan-ingest.py"
DOC="$ROOT/docs/PLAN_SCRIPT_BEHAVIOUR_RUNTIME.md"
TEST="$ROOT/tests/plan_script_behaviour_runtime_smoke.sh"

for f in "$HELPER" "$DOC" "$TEST"; do
  [[ -s "$f" ]] || { echo "missing script runtime artifact: $f" >&2; exit 1; }
done

for token in \
  "script-behaviour" "SCRIPT_BEHAVIOUR_SCHEMA" "queue.plan.script_behaviour.v1" \
  "looks_like_shell_script" "classify_script_behaviour" "BACKUP_JOB" \
  "DATABASE_MIGRATION" "DEPLOYMENT_ORCHESTRATION" "TEST_RUNNER" \
  "MAINTENANCE_JOB" "script_static_review_required" "curl_pipe_to_shell" \
  "static scan only"; do
  grep -q "$token" "$HELPER" "$DOC" "$TEST" || { echo "missing script runtime token: $token" >&2; exit 1; }
done

grep -q '".sh"' "$HELPER" || { echo "helper does not include .sh in text extensions" >&2; exit 1; }
grep -q 'no parallel cron scheduler' "$DOC" || { echo "runtime doc must preserve cron boundary" >&2; exit 1; }

echo "PASS plan_script_behaviour_runtime_static"
