#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-$(pwd)}"
OUT="$(mktemp)"
trap 'rm -f "$OUT"' EXIT
python3 "$ROOT/bin/queue-display-resource-note-audit.py" --root "$ROOT" --json > "$OUT"
python3 - "$OUT" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
assert data['schema'] == 'queuebash.display_resource_note_audit.v1'
assert data['status'] == 'ok'
assert data['summary']['audited_notes'] >= 1
assert data['resource_rendering'] is False
assert data['resource_body_read'] is False
assert data['token_substitution'] is False
assert data['secret_rendering'] is False
assert data['provider_calls'] is False
assert data['signing_mutation'] is False
assert data['install_mutation'] is False
assert data['permission_mutation'] is False
PY
echo "display_resource_note_audit_smoke: ok"
