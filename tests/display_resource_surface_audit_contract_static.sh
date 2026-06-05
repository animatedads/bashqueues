#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="bin/queue-display-resource-surface-audit.py"
schema="schemas/display_resource/resource_surface_audit_result.example.json"
[[ -x "$helper" ]]
[[ -f "$schema" ]]
grep -q 'queuebash.display_resource_surface_audit.v1' "$helper" "$schema"
grep -q 'none-surface-audit-only' "$helper" "$schema"
grep -q 'SURFACE_RE' "$helper"
grep -q 'surface_empty' "$helper"
grep -q 'surface_shell_expansion' "$helper"
grep -q 'surface_secret_word' "$helper"
grep -q 'surface_differs_by_language' "$helper"
grep -q 'duplicate_manifest_entry' "$helper"
# Bob18 boundary: helper must remain manifest-only, read-only, and presentation-only.
! grep -Eq 'chmod|chown|os\.chmod|os\.chown|subprocess|requests|urllib|render_template|Template\(|eval\(|exec\(' "$helper"
grep -q '"manifest_only": true' "$schema"
grep -q '"resource_rendering": false' "$schema"
grep -q '"resource_body_read": false' "$schema"
grep -q '"secret_rendering": false' "$schema"
grep -q '"json_contract_source": false' "$schema"
grep -q '"install_mutation": false' "$schema"
grep -q '"permission_mutation": false' "$schema"
