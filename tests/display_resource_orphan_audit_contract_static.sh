#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="bin/queue-display-resource-orphan-audit.py"
[ -f "$helper" ] || { echo "missing $helper" >&2; exit 1; }
grep -q 'queuebash.display_resource_orphan_audit.v1' "$helper"
grep -q 'none-orphan-audit-only' "$helper"
grep -q 'manifest-rows-and-resource-file-presence-only' "$helper"
grep -q 'file_content_read.*False' "$helper"
grep -q 'signing_mutation.*False' "$helper"
grep -q 'installer.*False' "$helper"
grep -q 'permission_mutation.*False' "$helper"
grep -q 'token_value_substitution.*False' "$helper"
grep -q 'unmanifested_resource_file' "$helper"
if grep -Eq '\b(chmod|chown|os\.chmod|os\.chown|subprocess|eval\(|exec\()\b' "$helper"; then
  echo "orphan audit helper must remain read-only and non-executing" >&2
  exit 1
fi
grep -q 'queuebash.display_resource_orphan_audit.v1' schemas/display_resource/resource_orphan_audit_result.example.json
