#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="bin/queue-display-resource-lookup-explain.py"
schema="schemas/display_resource/resource_lookup_explain_result.example.json"
[ -x "$helper" ]
[ -f "$schema" ]
grep -q 'queuebash.display_resource_lookup_explain.v1' "$helper"
grep -q 'queuebash.display_resource_lookup_explain.v1' "$schema"
grep -q 'renderer.*none-lookup-explain-only' "$helper"
grep -q 'manifest-metadata-and-file-presence-only' "$helper"
grep -q 'secret_rendering_allowed.*False' "$helper"
grep -q 'json_contract_source.*False' "$helper"
! grep -Eq 'eval\(|source |subprocess|os\.system|Popen|requests\.|urllib|http://' "$helper"
! grep -Eq 'QUEUEBASH_SECRET_[A-Z0-9_]+=|actual-secret|secret-value|BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16}' "$helper" "$schema"
