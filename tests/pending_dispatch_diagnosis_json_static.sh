#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

grep -q 'queuebash.dispatch_diagnosis.v1' queuebash.sh
grep -q '_queue_job_pending_dispatch_diagnose_json' queuebash.sh
grep -q '"dispatch_diagnosis"' queuebash.sh
grep -q 'QUEUEBASH_SUPPRESS_CLASS_AVAILABLE_EVENTS=1 _queue_class_available' queuebash.sh
grep -q 'system_modified":false' queuebash.sh

echo "pending_dispatch_diagnosis_json_static: ok"
