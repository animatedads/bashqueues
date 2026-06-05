#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "FAIL $*" >&2; exit 1; }
helper=bin/queue-plan-ingest.py
grep -q 'COLLECTORS_SCHEMA = "queue.plan.collectors.v1"' "$helper" || fail 'missing collectors schema'
grep -q 'def collector_contract_for_adapter' "$helper" || fail 'missing collector contract function'
grep -q 'QUEUE_PLAN_COLLECTOR_REVIEW' "$helper" || fail 'missing collector review gate'
grep -q 'queue plan collectors PATH \[--json\]' queuebash.sh || fail 'missing queuebash collectors usage comment'
grep -q 'queue plan collectors PATH \[--json\]' resources.d/display/lang_eng/plan-help.txt || fail 'missing plan help collectors command'
grep -q 'queue.plan.collectors.v1' docs/PLAN_COLLECTOR_CONTRACTS.md || fail 'missing collector doc schema'
grep -q 'no SDK/API/CLI/WinRM/SMB/RPC/REST/GraphQL/Kubernetes API calls' docs/PLAN_COLLECTOR_CONTRACTS.md || fail 'doc missing no-live boundary'
echo PASS tests/plan_collector_contract_static.sh
