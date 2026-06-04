#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
python3 bin/queue-display-resource-token-audit.py --root . --json > "$tmp"
grep -q '"schema": "queuebash.display_resource_token_audit.v1"' "$tmp"
grep -q '"status": "ok"' "$tmp"
grep -q '"renderer": "none-token-audit-only"' "$tmp"
grep -q '"source": "manifest-and-resource-token-names-only"' "$tmp"
grep -q '"redacted": true' "$tmp"
grep -q '"token_value_substitution": false' "$tmp"
grep -q '"secret_rendering_allowed": false' "$tmp"
grep -q '"json_contract_source": false' "$tmp"
grep -q '"undeclared_used_tokens": 0' "$tmp"
grep -q '"secret_token_names_present": false' "$tmp"
! grep -E 'actual-secret|secret-value|BEGIN PRIVATE KEY|AKIA[0-9A-Z]{16}' "$tmp"
echo "PASS display_resource_token_audit_smoke"
