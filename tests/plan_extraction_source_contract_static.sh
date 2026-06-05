#!/usr/bin/env bash
set -euo pipefail
root="${1:-.}"
helper="$root/bin/queue-plan-ingest.py"
doc="$root/docs/PLAN_EXTRACTION_SOURCE_CONTRACT.md"
qsh="$root/queuebash.sh"
[[ -f "$helper" ]] || { echo "missing queue-plan-ingest.py" >&2; exit 1; }
[[ -f "$doc" ]] || { echo "missing PLAN_EXTRACTION_SOURCE_CONTRACT.md" >&2; exit 1; }
grep -q 'SOURCES_SCHEMA = "queue.plan.sources.v1"' "$helper"
grep -q 'def source_contract_for_adapter' "$helper"
grep -q 'queue plan sources PATH' "$qsh"
grep -q 'safe_to_collect_here' "$doc"
grep -q 'must not open WinRM' "$doc"
grep -q 'must not create a parallel scheduler' "$doc"
echo "PASS plan extraction source contract static"
