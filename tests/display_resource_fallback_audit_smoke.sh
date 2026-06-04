#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp)"
python3 bin/queue-display-resource-fallback-audit.py --root . --json > "$tmp"
python3 - "$tmp" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1]))
assert payload["schema"] == "queuebash.display_resource_fallback_audit.v1"
assert payload["status"] == "ok", payload.get("findings")
assert payload["redacted"] is True
assert payload["renderer"] == "none-fallback-audit-only"
assert payload["source"] == "manifest-metadata-and-file-presence-only"
assert payload["json_contract_source"] is False
assert payload["secret_rendering_allowed"] is False
assert payload["token_value_substitution"] is False
assert payload["stats"]["fallback_required_resources"] >= 1
assert payload["stats"]["fallback_present_resources"] == payload["stats"]["fallback_required_resources"]
assert any(r["name"] == "queue-version.txt" and r["fallback_file_present"] for r in payload["resources"])
for text in json.dumps(payload).splitlines():
    assert "actual-secret" not in text.lower()
    assert "secret-value" not in text.lower()
PY
rm -f "$tmp"
