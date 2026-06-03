#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

out="$(mktemp)"
python3 bin/queue-display-resource-lint.py --root . --json > "$out"
grep -q '"schema": "queuebash.display_resource_lint.v1"' "$out"
grep -q '"status": "ok"' "$out"
grep -q '"redacted": true' "$out"
python3 tests/display_resource_lint_json_contract_static.py >/tmp/display_resource_lint_json.out
grep -q 'PASS display_resource_lint_json_contract_static' /tmp/display_resource_lint_json.out
rm -f "$out"
echo "PASS display_resource_lint_smoke"
