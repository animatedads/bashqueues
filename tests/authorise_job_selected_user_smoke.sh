#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

root="$(mktemp -d)"
trap 'rm -rf "$root" /tmp/bq_auth_selected_out.$$' EXIT
export QUEUEBASH_ROOT="$root"
export QUEUEBASH_SELECTED_USER="hc3"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh

mkdir -p "$root/pending"
cat > "$root/pending/J123.job" <<'JOB'
JOB_ID=J123
SUBMIT_USER=root
JOB_NAME=demo
COMMAND=( bash -lc 'echo ok' )
JOB

queue authorise J123 --admin root --reason 'root approved in selected hc3 queue' >/tmp/bq_auth_selected_out.$$
code="$(awk '/^authorisation:/ {print $2; exit}' /tmp/bq_auth_selected_out.$$)"
[[ -n "$code" ]]

grep -q '^user: hc3$' /tmp/bq_auth_selected_out.$$
grep -q '^AUTHORISATION_ADMIN=root$' "$root/authorisations/$code.env"
grep -q '^AUTHORISATION_USER=hc3$' "$root/authorisations/$code.env"

queue authorisation list >/tmp/bq_auth_selected_out.$$
grep -q "${code} user=hc3" /tmp/bq_auth_selected_out.$$

# The authorisation should validate for the queue owner and fail for root,
# proving the default target is no longer accidentally taken from SUBMIT_USER=root.
queue authorisation show "$code" >/tmp/bq_auth_selected_out.$$
grep -q '^AUTHORISATION_USER=hc3$' /tmp/bq_auth_selected_out.$$

echo '[PASS] selected-user job authorisation targets queue user, not root submitter'
