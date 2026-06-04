#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="bin/queue-display-resource-fallback-audit.py"
schema="schemas/display_resource/resource_fallback_audit_result.example.json"
[[ -x "$helper" ]]
[[ -f "$schema" ]]
grep -q 'queuebash.display_resource_fallback_audit.v1' "$helper"
grep -q 'queuebash.display_resource_fallback_audit.v1' "$schema"
grep -q 'none-fallback-audit-only' "$helper"
grep -q 'manifest-metadata-and-file-presence-only' "$helper"
grep -q 'secret_rendering_allowed.*False' "$helper"
grep -q 'token_value_substitution.*False' "$helper"
! grep -Eq '\beval\b|\bsource\b|subprocess|os\.system|Popen|requests\.|urllib\.|http://' "$helper"
! grep -Eq 'SECRET_[A-Z0-9_]+=|PASSWORD=|AKIA[0-9A-Z]{16}|BEGIN .*PRIVATE KEY' "$helper" "$schema"
python3 -m py_compile "$helper"
