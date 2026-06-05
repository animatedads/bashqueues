#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="bin/queue-display-resource-line-audit.py"
[ -f "$helper" ] || { echo "missing $helper" >&2; exit 1; }
grep -q 'queuebash.display_resource_line_audit.v1' "$helper"
grep -q 'none-line-audit-only' "$helper"
grep -q 'manifest-listed-resource-text-line-hygiene-only' "$helper"
grep -q 'manifest-listed-display-xml-resource-text-for-line-hygiene-only' "$helper"
grep -q 'resource_rendering.*False' "$helper"
grep -q 'signing_mutation.*False' "$helper"
grep -q 'installer.*False' "$helper"
grep -q 'permission_mutation.*False' "$helper"
grep -q 'token_value_substitution.*False' "$helper"
grep -q 'trailing_whitespace' "$helper"
grep -q 'overlong_line' "$helper"
grep -q 'xml_tab_indentation' "$helper"
if grep -Eq '\b(chmod|chown|os\.chmod|os\.chown|subprocess|eval\(|exec\()\b' "$helper"; then
  echo "line audit helper must remain read-only and non-executing" >&2
  exit 1
fi
grep -q 'queuebash.display_resource_line_audit.v1' schemas/display_resource/resource_line_audit_result.example.json
