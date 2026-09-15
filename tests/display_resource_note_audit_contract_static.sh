#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-$(pwd)}"
HELPER="$ROOT/bin/queue-display-resource-note-audit.py"
SCHEMA="$ROOT/schemas/display_resource/resource_note_audit_result.example.json"
[[ -f "$HELPER" ]] || { echo "missing helper: $HELPER" >&2; exit 1; }
[[ -x "$HELPER" ]] || { echo "helper is not executable: $HELPER" >&2; exit 1; }
[[ -f "$SCHEMA" ]] || { echo "missing schema example: $SCHEMA" >&2; exit 1; }
grep -q 'queuebash.display_resource_note_audit.v1' "$HELPER"
grep -q 'queuebash.display_resource_note_audit.v1' "$SCHEMA"
grep -q 'resource_rendering.*False' "$HELPER"
grep -q 'resource_body_read.*False' "$HELPER"
grep -q 'token_substitution.*False' "$HELPER"
grep -q 'secret_rendering.*False' "$HELPER"
grep -q 'provider_calls.*False' "$HELPER"
grep -q 'signing_mutation.*False' "$HELPER"
grep -q 'install_mutation.*False' "$HELPER"
grep -q 'permission_mutation.*False' "$HELPER"
if grep -Eq 'os\.system|subprocess|eval\(|exec\(|chmod\(|chown\(|unlink\(|rename\(|replace\(|rmtree|copytree|shutil\.copy' "$HELPER"; then
  echo "helper contains forbidden execution/mutation primitive" >&2
  exit 1
fi
if grep -Eq 'SECRET_VALUE|actual-secret|BEGIN PRIVATE KEY' "$SCHEMA"; then
  echo "schema example appears to contain concrete secret material" >&2
  exit 1
fi
echo "display_resource_note_audit_contract_static: ok"
