#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="bin/queue-display-resource-coverage.py"
test -x "$helper"
grep -q 'queuebash.display_resource_coverage.v1' "$helper"
grep -q 'none-coverage-only' "$helper"
grep -q 'manifest-metadata-only' "$helper"
grep -q 'secret_rendering_allowed' "$helper"
grep -q 'json_contract_source' "$helper"
grep -q 'provider_calls' "$helper"
grep -q 'signing_mutation' "$helper"
! grep -E 'subprocess|os\.system|eval\(|exec\(|requests|urllib|http://' "$helper"
! grep -E 'actual-secret|secret-value|BEGIN PRIVATE KEY|AKIA[0-9A-Z]{16}' "$helper" schemas/display_resource/resource_coverage_result.example.json
grep -q 'Display resource coverage helper' docs/QUEUE_DISPLAY_RESOURCES.md
grep -q 'display_resource_coverage.v1' docs/QUEUE_XML_RESOURCES.md
echo "PASS display_resource_coverage_contract_static"
