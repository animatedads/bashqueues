#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="bin/queue-display-resource-permission-audit.py"
schema="schemas/display_resource/resource_permission_audit_result.example.json"
test -x "$helper"
test -f "$schema"
grep -q 'queuebash.display_resource_permission_audit.v1' "$helper"
grep -q 'none-permission-audit-only' "$helper"
grep -q 'manifest-metadata-and-filesystem-mode-only' "$helper"
grep -q 'permission_mutation.*False' "$helper"
grep -q 'installer.*False' "$helper"
grep -q 'signing_mutation.*False' "$helper"
grep -q 'token_value_substitution.*False' "$helper"
grep -q 'secret_rendering_allowed.*False' "$helper"
grep -q 'json_contract_source.*False' "$helper"
grep -q 'chmod_mutation' "$helper"
! grep -Eq 'chmod\(|os\.chmod|subprocess|os\.system|Popen|requests|urllib|curl|wget|ssh' "$helper"
! grep -Eq 'QUEUEBASH_SECRET_[A-Z0-9_]+=|actual[-_ ]?secret|BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16}' "$schema" docs/QUEUE_DISPLAY_RESOURCES.md docs/QUEUE_XML_RESOURCES.md
