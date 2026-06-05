#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "[FAIL] $*" >&2; exit 1; }

[[ -x bin/queue-vcs-assert ]] || fail 'queue-vcs-assert helper missing or not executable'
bash -n bin/queue-vcs-assert || fail 'queue-vcs-assert syntax failed'
bash -n queuebash.sh || fail 'queuebash syntax failed'

grep -q 'queuebash.vcs.assert.v1' bin/queue-vcs-assert || fail 'assert helper missing JSON schema'
grep -q 'read_only' bin/queue-vcs-assert || fail 'assert helper must declare read_only'
grep -q 'queue-vcs-assert' queuebash.sh || fail 'queue command surface missing assert helper'
grep -q 'assert|verify' queuebash.sh || fail 'queue vcs assert subcommand missing'
grep -q '"helpers":\["queue-vcs-detect","queue-vcs-probe","queue-vcs-assert"\]' queuebash.sh || fail 'queue vcs types JSON missing helper metadata'
grep -q 'QUEUEBASH_VCS_AUDIT_FINGERPRINT' classes/VCS_CHANGESET_AUDIT.env || fail 'audit class missing fingerprint env gate'
grep -q 'queue_class_shared_asset vcs fingerprint' classes/VCS_CHANGESET_AUDIT.env || fail 'audit class missing fingerprint asset gate'
grep -q 'queuebash.vcs.assert.v1' docs/VCS_TENANT_CONTRACT.md || fail 'contract missing assert JSON schema'

echo '[PASS] VCS assert command JSON static contract is wired'
