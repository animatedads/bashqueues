#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="bin/queue-display-resource-encoding-audit.py"
[ -f "$helper" ] || { echo "missing $helper" >&2; exit 1; }
grep -q 'queuebash.display_resource_encoding_audit.v1' "$helper"
grep -q 'none-encoding-audit-only' "$helper"
grep -q 'manifest-listed-resource-bytes-for-encoding-only' "$helper"
grep -q 'manifest-listed-display-xml-resource-bytes-only' "$helper"
grep -q 'resource_rendering.*False' "$helper"
grep -q 'signing_mutation.*False' "$helper"
grep -q 'installer.*False' "$helper"
grep -q 'permission_mutation.*False' "$helper"
grep -q 'token_value_substitution.*False' "$helper"
grep -q 'utf8_invalid' "$helper"
grep -q 'nul_byte' "$helper"
grep -q 'crlf_line_endings' "$helper"
if grep -Eq '\b(chmod|chown|os\.chmod|os\.chown|subprocess|eval\(|exec\()\b' "$helper"; then
  echo "encoding audit helper must remain read-only and non-executing" >&2
  exit 1
fi
grep -q 'queuebash.display_resource_encoding_audit.v1' schemas/display_resource/resource_encoding_audit_result.example.json
