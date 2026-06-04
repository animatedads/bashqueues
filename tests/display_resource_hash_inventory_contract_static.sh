#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="bin/queue-display-resource-hash-inventory.py"
[ -f "$helper" ] || { echo "missing $helper" >&2; exit 1; }
grep -q 'queuebash.display_resource_hash_inventory.v1' "$helper"
grep -q 'hashlib.sha256' "$helper"
grep -q 'none-hash-inventory-only' "$helper"
grep -q 'manifest-listed-files-and-sha256-only' "$helper"
grep -q 'signing_mutation.*False' "$helper"
grep -q 'installer.*False' "$helper"
grep -q 'permission_mutation.*False' "$helper"
grep -q 'token_value_substitution.*False' "$helper"
if grep -Eq '\b(chmod|chown|os\.chmod|os\.chown|subprocess|eval\(|exec\(|source )\b' "$helper"; then
  echo "hash inventory helper must remain read-only and non-executing" >&2
  exit 1
fi
grep -q 'queuebash.display_resource_hash_inventory.v1' schemas/display_resource/resource_hash_inventory_result.example.json
