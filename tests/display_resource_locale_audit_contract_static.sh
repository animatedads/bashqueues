#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="bin/queue-display-resource-locale-audit.py"
schema="schemas/display_resource/resource_locale_audit_result.example.json"
[[ -x "$helper" ]]
[[ -f "$schema" ]]
grep -q 'queuebash.display_resource_locale_audit.v1' "$helper" "$schema"
grep -q 'none-locale-audit-only' "$helper" "$schema"
grep -q 'LANGUAGE_RE' "$helper"
grep -q 'fallback_language_unmanifested' "$helper"
grep -q 'language_directory_missing' "$helper"
grep -q 'duplicate_manifest_entry' "$helper"
# Bob18 boundary: helper must remain read-only and presentation-only.
! grep -Eq 'chmod|chown|os\.chmod|os\.chown|subprocess|requests|urllib|render_template|Template\(|eval\(|exec\(' "$helper"
grep -q '"secret_rendering": false' "$schema"
grep -q '"json_contract_source": false' "$schema"
grep -q '"install_mutation": false' "$schema"
grep -q '"permission_mutation": false' "$schema"
