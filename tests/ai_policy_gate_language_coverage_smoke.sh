#!/usr/bin/env bash
set -euo pipefail

ROOT="${TMPDIR:-/tmp}/queuebash-ai-policy-lang-$$"
WORK="$ROOT/work"
QROOT="$ROOT/qroot"
mkdir -p "$WORK" "$QROOT/pending/p0999999990"
trap 'rm -rf "$ROOT"' EXIT

write_job() {
  local id="$1" name="$2"
  shift 2
  local job="$QROOT/pending/p0999999990/${id}.job"
  {
    echo "JOB_ID='$id'"
    echo "JOB_NAME='$name'"
    echo "PRIORITY='10'"
    echo "PWD_AT_SUBMIT='$WORK'"
    printf 'COMMAND=(' 
    for arg in "$@"; do printf ' %q' "$arg"; done
    printf ' )\n'
  } > "$job"
}

expect_findings() {
  local id="$1"; shift
  local out="$ROOT/${id}.json"
  QUEUEBASH_ROOT="$QROOT" bin/queue-ai-policy-gate examine --job-id "$id" > "$out"
  python3 - "$out" "$@" <<'PYEXPECT'
import json, sys
path = sys.argv[1]
need = sys.argv[2:]
data = json.load(open(path))
ids = {f.get('id') for f in data.get('findings', [])}
cats = {f.get('category') for f in data.get('findings', [])}
langs = set(data.get('job_type_plan', {}).get('languages', []))
missing = [x for x in need if x not in ids and x not in cats and x not in langs]
if missing:
    print('missing', missing, 'ids', sorted(ids), 'cats', sorted(cats), 'langs', sorted(langs))
    sys.exit(1)
PYEXPECT
}

cat > "$WORK/app.js" <<'JS'
const fs = require('fs');
const child_process = require('child_process');
const sql = Buffer.from(fs.readFileSync('payload.b64', 'utf8'), 'base64').toString();
db.query(sql);
child_process.execSync('echo checked');
JS
write_job lang_js jsjob node app.js
expect_findings lang_js javascript javascript_file_payload_read javascript_base64_decode javascript_database_execute javascript_child_process

cat > "$WORK/audit.ps1" <<'PS'
$raw = Get-Content .\payload.b64
$sql = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($raw))
Invoke-Sqlcmd -Query $sql
Invoke-WebRequest http://example.invalid
PS
write_job lang_ps psjob pwsh -File audit.ps1
expect_findings lang_ps powershell powershell_file_payload_read powershell_base64_decode powershell_sql_execute powershell_network_client

cat > "$WORK/migrate.php" <<'PHP'
<?php
$sql = base64_decode(file_get_contents('payload.b64'));
mysqli_query($db, $sql);
shell_exec('echo audit');
?>
PHP
write_job lang_php phpjob php migrate.php
expect_findings lang_php php php_file_payload_read php_base64_decode php_database_execute php_subprocess_execution

cat > "$WORK/migrate.rb" <<'RB'
require 'base64'
sql = Base64.decode64(File.read('payload.b64'))
conn.exec(sql)
system('echo audit')
RB
write_job lang_rb rbjob ruby migrate.rb
expect_findings lang_rb ruby ruby_file_payload_read ruby_base64_decode ruby_database_execute ruby_subprocess_execution

cat > "$WORK/migrate.pl" <<'PL'
use MIME::Base64;
open my $fh, '<', 'payload.b64';
my $sql = decode_base64(join('', <$fh>));
$dbh->do($sql);
system('echo audit');
PL
write_job lang_pl pljob perl migrate.pl
expect_findings lang_pl perl perl_file_payload_read perl_base64_decode perl_database_execute perl_subprocess_execution

cat > "$WORK/main.go" <<'GO'
package main
import (
  "encoding/base64"
  "os"
  "database/sql"
  "os/exec"
)
func main(){ b,_ := os.ReadFile("payload.b64"); s,_ := base64.StdEncoding.DecodeString(string(b)); db.Query(string(s)); exec.Command("echo", "audit").Run(); }
GO
write_job lang_go gojob go main.go
expect_findings lang_go go go_file_payload_read go_base64_decode go_database_execute go_subprocess_execution

echo "PASS ai policy gate expanded language coverage smoke"
