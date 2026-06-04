#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="bin/queue-display-resource-token-audit.py"
test -x "$helper"
grep -q 'queuebash.display_resource_token_audit.v1' "$helper"
grep -q 'none-token-audit-only' "$helper"
grep -q 'token_value_substitution' "$helper"
grep -q 'SECRET_TOKEN_RE' "$helper"
grep -q 'json_contract_source' "$helper"
grep -q 'secret_rendering_allowed' "$helper"
! grep -Eq 'subprocess\.|os\.system|eval\(|exec\(' "$helper"
! grep -Eq 'QUEUEBASH_SECRET_[A-Z0-9_]+=|actual-secret|secret-value|BEGIN PRIVATE KEY|AKIA[0-9A-Z]{16}' \
  schemas/display_resource/resource_token_audit_result.example.json
! grep -E '\$\{|\$\(|`' resources.d/display/lang_eng/status-panel.example.txt resources.d/xml/lang_eng/job-card.example.xml
echo "PASS display_resource_token_audit_contract_static"
