#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/resources.d/display/lang_eng" "$tmp/resources.d/display/fallback" "$tmp/resources.d/xml/lang_eng" "$tmp/resources.d/xml/fallback"
cat > "$tmp/resources.d/display/manifest.example.tsv" <<'TSV'
display	status.txt	lang_eng	yes	JOB	status panel	false	false	ok
display	status.txt	fallback	no	JOB	status panel	false	false	ok
TSV
cat > "$tmp/resources.d/xml/manifest.example.tsv" <<'TSV'
xml	job.xml	lang_eng	yes	JOB	xml job card	false	false	ok
xml	job.xml	fallback	no	JOB	xml job card	false	false	ok
TSV
printf 'status {{JOB}}\n' > "$tmp/resources.d/display/lang_eng/status.txt"
printf 'fallback {{JOB}}\n' > "$tmp/resources.d/display/fallback/status.txt"
printf '<job>{{JOB}}</job>\n' > "$tmp/resources.d/xml/lang_eng/job.xml"
printf '<job>{{JOB}}</job>\n' > "$tmp/resources.d/xml/fallback/job.xml"
out="$tmp/out.json"
python3 bin/queue-display-resource-surface-audit.py --root "$tmp" --json > "$out"
python3 - "$out" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
assert data['schema'] == 'queuebash.display_resource_surface_audit.v1'
assert data['status'] == 'ok', data
assert data['summary']['errors'] == 0, data['findings']
assert data['manifest_only'] is True
assert data['resource_rendering'] is False
assert data['resource_body_read'] is False
assert data['token_substitution'] is False
assert data['secret_rendering'] is False
assert data['provider_calls'] is False
assert data['signing_mutation'] is False
assert data['install_mutation'] is False
assert data['permission_mutation'] is False
assert len(data['surfaces']) == 4
PY
bad="$tmp/bad"
mkdir -p "$bad/resources.d/display/lang_eng" "$bad/resources.d/xml/lang_eng" "$bad/resources.d/xml/fallback"
cat > "$bad/resources.d/display/manifest.example.tsv" <<'TSV'
display	status.txt	lang_eng	yes	JOB		false	false	bad
display	status.txt	lang_eng	yes	JOB	$(whoami)	false	false	bad
display	status.txt	fallback	no	JOB	password prompt	false	false	review
TSV
cat > "$bad/resources.d/xml/manifest.example.tsv" <<'TSV'
xml	job.xml	lang_eng	yes	JOB	actual-secret-value	false	false	bad
xml	job.xml	fallback	no	JOB	fallback xml	false	false	ok
TSV
if python3 bin/queue-display-resource-surface-audit.py --root "$bad" --json > "$tmp/bad.json"; then
  echo "expected bad surface audit fixture to fail" >&2
  exit 1
fi
python3 - "$tmp/bad.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
assert data['status'] == 'error'
codes = {finding['code'] for finding in data['findings']}
assert 'surface_empty' in codes, codes
assert 'surface_shell_expansion' in codes, codes
assert 'surface_secret_word' in codes, codes
assert 'surface_secret_value' in codes, codes
assert 'duplicate_manifest_entry' in codes, codes
PY
