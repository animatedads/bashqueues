#!/usr/bin/env bash
set -euo pipefail
root="${1:-.}"
helper="$root/bin/queue-plan-ingest.py"
out="$(${QUEUEBASH_PYTHON:-python3} "$helper" sources "$root/fixtures/plan/runtime/windows-task-scheduler.txt" --json)"
printf '%s\n' "$out" | grep -q '"schema":"queue.plan.sources.v1"'
printf '%s\n' "$out" | grep -q 'windows-task-scheduler'
printf '%s\n' "$out" | grep -q 'safe_to_collect_here'
printf '%s\n' "$out" | grep -q 'external_winrm_or_smb_rpc_exporter'
out2="$(${QUEUEBASH_PYTHON:-python3} "$helper" sources "$root/fixtures/plan/runtime/local-cron-status.txt" --json)"
printf '%s\n' "$out2" | grep -q 'existing_cron_bridge'
printf '%s\n' "$out2" | grep -q 'existing_bashqueues_cron_model'
echo "PASS plan extraction source contract smoke"
