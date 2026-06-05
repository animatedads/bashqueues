#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/resources.d/display/lang_eng" "$tmp/resources.d/display/fallback" "$tmp/resources.d/xml/lang_eng" "$tmp/resources.d/xml/fallback"
cat > "$tmp/resources.d/display/manifest.example.tsv" <<'EOF'
# resource_type	name	language	fallback_required	tokens	surface	json_contract_source	secret_rendering_allowed	notes
display	known.txt	lang_eng	yes	NAME	demo surface	false	false	smoke fixture
display	known.txt	fallback	no	NAME	fallback demo surface	false	false	smoke fixture fallback
EOF
cat > "$tmp/resources.d/xml/manifest.example.tsv" <<'EOF'
# resource_type	name	language	fallback_required	tokens	surface	json_contract_source	secret_rendering_allowed	notes
xml	known.xml	lang_eng	yes	NAME	demo xml surface	false	false	smoke fixture
xml	known.xml	fallback	no	NAME	fallback demo xml surface	false	false	smoke fixture fallback
EOF
printf 'Hello {{NAME}}\n' > "$tmp/resources.d/display/lang_eng/known.txt"
printf 'Hello fallback {{NAME}}\n' > "$tmp/resources.d/display/fallback/known.txt"
printf '<card>{{NAME}}</card>\n' > "$tmp/resources.d/xml/lang_eng/known.xml"
printf '<card>{{NAME}}</card>\n' > "$tmp/resources.d/xml/fallback/known.xml"
out="$tmp/encoding-audit.json"
python3 bin/queue-display-resource-encoding-audit.py --root "$tmp" --json > "$out"
python3 - "$out" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1]))
assert payload["schema"] == "queuebash.display_resource_encoding_audit.v1"
assert payload["status"] == "ok", payload["status"]
assert payload["read_only"] is True
assert payload["renderer"] == "none-encoding-audit-only"
assert payload["source"] == "manifest-listed-resource-bytes-for-encoding-only"
assert payload["resource_rendering"] is False
assert payload["secret_rendering_allowed"] is False
assert payload["token_value_substitution"] is False
assert payload["file_content_read_scope"] == "manifest-listed-display-xml-resource-bytes-only"
assert payload["stats"]["resource_files_audited"] == 4, payload["stats"]
assert payload["stats"]["utf8_invalid"] == 0, payload["stats"]
assert all(r["utf8_valid"] for r in payload["resources"]), payload["resources"]
PY
printf 'bad\r\n' > "$tmp/resources.d/display/lang_eng/known.txt"
if python3 bin/queue-display-resource-encoding-audit.py --root "$tmp" --json > "$out"; then
  :
fi
python3 - "$out" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1]))
assert payload["status"] == "warning", payload["status"]
assert any(f["code"] == "crlf_line_endings" for f in payload["findings"]), payload["findings"]
PY
