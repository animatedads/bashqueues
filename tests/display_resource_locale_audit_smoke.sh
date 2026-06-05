#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/resources.d/display/lang_eng" "$tmp/resources.d/display/fallback" "$tmp/resources.d/xml/lang_eng" "$tmp/resources.d/xml/fallback"
cat > "$tmp/resources.d/display/manifest.example.tsv" <<'TSV'
display	status.txt	lang_eng	yes	JOB	status	false	false	ok
display	status.txt	fallback	no	JOB	fallback status	false	false	ok
TSV
cat > "$tmp/resources.d/xml/manifest.example.tsv" <<'TSV'
xml	job.xml	lang_eng	yes	JOB	xml status	false	false	ok
xml	job.xml	fallback	no	JOB	fallback xml	false	false	ok
TSV
printf 'status {{JOB}}\n' > "$tmp/resources.d/display/lang_eng/status.txt"
printf 'fallback {{JOB}}\n' > "$tmp/resources.d/display/fallback/status.txt"
printf '<job>{{JOB}}</job>\n' > "$tmp/resources.d/xml/lang_eng/job.xml"
printf '<job>{{JOB}}</job>\n' > "$tmp/resources.d/xml/fallback/job.xml"
out="$tmp/out.json"
python3 bin/queue-display-resource-locale-audit.py --root "$tmp" --json > "$out"
python3 - "$out" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
assert data['schema'] == 'queuebash.display_resource_locale_audit.v1'
assert data['status'] == 'ok', data
assert data['summary']['errors'] == 0, data['findings']
assert data['resource_rendering'] is False
assert data['token_substitution'] is False
assert data['secret_rendering'] is False
assert data['provider_calls'] is False
assert data['signing_mutation'] is False
assert data['install_mutation'] is False
langs = {item['resource_type']: item for item in data['resources']}
assert langs['display']['languages_in_manifest'] == ['fallback', 'lang_eng']
assert langs['xml']['fallback_directory_present'] is True
PY
# Broken fixture must fail closed on missing fallback directory / malformed language.
bad="$tmp/bad"
mkdir -p "$bad/resources.d/display/lang_eng" "$bad/resources.d/xml/lang_eng" "$bad/resources.d/xml/fallback"
cat > "$bad/resources.d/display/manifest.example.tsv" <<'TSV'
display	status.txt	lang-bad	yes	JOB	status	false	false	bad language
display	status.txt	lang_eng	yes	JOB	status	false	false	missing fallback
TSV
cat > "$bad/resources.d/xml/manifest.example.tsv" <<'TSV'
xml	job.xml	lang_eng	yes	JOB	xml status	false	false	ok
xml	job.xml	fallback	no	JOB	fallback xml	false	false	ok
TSV
printf 'status\n' > "$bad/resources.d/display/lang_eng/status.txt"
printf '<job/>\n' > "$bad/resources.d/xml/lang_eng/job.xml"
printf '<job/>\n' > "$bad/resources.d/xml/fallback/job.xml"
if python3 bin/queue-display-resource-locale-audit.py --root "$bad" --json > "$tmp/bad.json"; then
  echo "expected bad locale audit fixture to fail" >&2
  exit 1
fi
python3 - "$tmp/bad.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
assert data['status'] == 'error'
codes = {finding['code'] for finding in data['findings']}
assert 'language_identifier_invalid' in codes, codes
assert 'fallback_directory_missing' in codes or 'fallback_language_unmanifested' in codes, codes
PY
