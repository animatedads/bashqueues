#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="${TMPDIR:-/tmp}/queuebash-wave10-smoke-$$"
rm -rf "$QUEUEBASH_ROOT"
# shellcheck disable=SC1091
source ./queuebash.sh

set +e
acl_out="$(queue acl set module provider:example job.submit alice '*' --decision allow 2>&1)"
acl_rc=$?
mod_out="$(queue module acl set provider example job.submit alice 2>&1)"
mod_rc=$?
set -e

[[ "$acl_rc" -eq 3 ]]
[[ "$mod_rc" -eq 3 ]]
printf '%s\n' "$acl_out" | grep -Fq 'queue acl set: provider ACL contract handoff'
printf '%s\n' "$acl_out" | grep -Fq 'Provider modules must implement this as normalized data, never shell.'
printf '%s\n' "$mod_out" | grep -Fq 'queue module acl: operation ACL handoff'
printf '%s\n' "$mod_out" | grep -Fq 'No ACL backend is active in this build, so no policy was changed.'
rm -rf "$QUEUEBASH_ROOT"
