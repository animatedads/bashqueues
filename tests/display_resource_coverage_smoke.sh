#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
python3 bin/queue-display-resource-coverage.py --root . --json > "$tmp"
grep -q '"schema": "queuebash.display_resource_coverage.v1"' "$tmp"
grep -q '"status": "ok"' "$tmp"
grep -q '"renderer": "none-coverage-only"' "$tmp"
grep -q '"source": "manifest-metadata-only"' "$tmp"
grep -q '"redacted": true' "$tmp"
grep -q '"secret_rendering_allowed": false' "$tmp"
grep -q '"json_contract_source": false' "$tmp"
grep -q '"language_dirs"' "$tmp"
grep -q '"resources"' "$tmp"
! grep -E 'actual-secret|secret-value|BEGIN PRIVATE KEY|AKIA[0-9A-Z]{16}' "$tmp"
echo "PASS display_resource_coverage_smoke"
