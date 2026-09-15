#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

grep -q 'queuebash.platform_matrix.v1' queuebash.sh
grep -q '_queue_platform_matrix_command' queuebash.sh
grep -q 'matrix|support|support-matrix' queuebash.sh
grep -q 'native Windows workers are not supported yet' queuebash.sh
grep -Fq '"command": "queue platform matrix [--json]"' policies.d/platform/windows-runtime-parity.json
grep -Fq '"must_report_native_windows_worker_supported": false' policies.d/platform/windows-runtime-parity.json
grep -q 'queuebash.platform_matrix.v1' docs/WINDOWS_SUPPORT_MATRIX.md

if grep -Fq 'native_windows_support_claim=true' queuebash.sh docs/WINDOWS_SUPPORT_MATRIX.md; then
    echo 'unexpected native Windows worker support claim' >&2
    exit 1
fi
if grep -Fq '"platform_id":"native-windows-powershell","family":"native_windows","support_tier":"W3","runtime_supported":true' queuebash.sh; then
    echo 'unexpected native Windows runtime support true claim' >&2
    exit 1
fi

echo 'PASS windows platform matrix static'
