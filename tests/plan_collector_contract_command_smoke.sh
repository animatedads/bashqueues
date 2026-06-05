#!/usr/bin/env bash
set -euo pipefail
out="$(QUEUEBASH_ALLOW_NONINTERACTIVE=1 bash -lc 'source ./queuebash.sh >/tmp/queue_plan_collectors_src.out 2>/tmp/queue_plan_collectors_src.err; queue plan collectors fixtures/plan/runtime/collector-contracts --json')"
printf '%s
' "$out" | grep -q '"schema":"queue.plan.collectors.v1"'
printf '%s
' "$out" | grep -q 'safe_to_collect_here":false'
echo PASS tests/plan_collector_contract_command_smoke.sh
