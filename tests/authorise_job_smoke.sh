#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

root="$(mktemp -d)"
trap 'rm -rf "$root" /tmp/bq_auth_job_out.$$ /tmp/bq_auth_job_err.$$' EXIT
export QUEUEBASH_ROOT="$root"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh

queue submit auth_job --reason 'baseline submit' -- bash -lc 'echo ok' >/tmp/bq_auth_job_out.$$
qid="$(basename "$root"/pending/*.job .job)"
job="$root/pending/$qid.job"
before_owner="$(stat -c '%u:%g' "$job")"

queue authorise "$qid" --reason 'operator approved existing job' >/tmp/bq_auth_job_out.$$
grep -q '^authorised:' /tmp/bq_auth_job_out.$$
grep -q '^SECURITY_AUTHORISATION_CODE=' "$job"
after_owner="$(stat -c '%u:%g' "$job")"
[[ "$before_owner" == "$after_owner" ]]

queue authorisation list >/tmp/bq_auth_job_out.$$
grep -q 'integrity=valid-' /tmp/bq_auth_job_out.$$
code="$(basename "$root"/authorisations/*.env .env)"

sed -i 's/echo/printf/' "$root/authorisations/$code.env"
queue authorisation list >/tmp/bq_auth_job_out.$$
grep -q 'integrity=invalid-command-hash' /tmp/bq_auth_job_out.$$
queue authorisation show "$code" >/tmp/bq_auth_job_out.$$
grep -q '^AUTHORISATION_FILE_INTEGRITY=invalid-command-hash$' /tmp/bq_auth_job_out.$$

echo '[PASS] existing job authorisation preserves job ownership and detects tampered command files'
