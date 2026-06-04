#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
python3 bin/queue-display-resource-lookup-explain.py --root . --type display --name queue-version.txt --language lang_eng --json > "$tmp"
python3 - "$tmp" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1]))
assert payload["schema"] == "queuebash.display_resource_lookup_explain.v1"
assert payload["status"] == "ok"
assert payload["resolution"]["state"] == "localized"
assert payload["resolution"]["selected_language"] == "lang_eng"
assert payload["renderer"] == "none-lookup-explain-only"
assert payload["secret_rendering_allowed"] is False
assert payload["json_contract_source"] is False
text = json.dumps(payload)
assert "actual-secret" not in text.lower()
assert "secret-value" not in text.lower()
PY
python3 bin/queue-display-resource-lookup-explain.py --root . --type display --name queue-version.txt --language lang_xx --json > "$tmp"
python3 - "$tmp" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1]))
assert payload["status"] == "ok"
assert payload["resolution"]["state"] == "fallback"
assert payload["resolution"]["fallback_used"] is True
assert payload["resolution"]["selected_language"] == "fallback"
PY
if python3 bin/queue-display-resource-lookup-explain.py --root . --type display --name missing-help.txt --language lang_eng --json > "$tmp"; then
  echo "missing resource unexpectedly succeeded" >&2
  exit 1
fi
python3 - "$tmp" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1]))
assert payload["status"] == "error"
assert any(f["code"] == "resource_not_declared" for f in payload["findings"])
PY
