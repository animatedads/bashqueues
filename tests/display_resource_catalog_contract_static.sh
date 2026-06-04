#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="bin/queue-display-resource-catalog.py"
[ -x "$helper" ]
grep -q 'queuebash.display_resource_catalog.v1' "$helper"
grep -q 'none-catalog-only' "$helper"
grep -q 'json_contract_source.*False' "$helper"
grep -q 'secret_rendering_allowed.*False' "$helper"
! grep -Eq 'eval\(|exec\(|subprocess|os\.system|source ' "$helper"
! grep -Eq 'read_text\(|open\([^)]*resources\.d/(display|xml)' "$helper"
grep -q 'queue-display-resource-catalog.py' docs/QUEUE_DISPLAY_RESOURCES.md
grep -q 'XML catalog evidence' docs/QUEUE_XML_RESOURCES.md
[ -f schemas/display_resource/resource_catalog_result.example.json ]
echo "PASS display_resource_catalog_contract_static"
