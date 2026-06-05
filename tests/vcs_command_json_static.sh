#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "[FAIL] $*" >&2; exit 1; }

grep -q '_queue_vcs_command' queuebash.sh || fail 'queue vcs command function missing'
grep -q 'vcs|version-control|version_control)' queuebash.sh || fail 'queue command dispatcher missing vcs alias'
grep -q 'queuebash.vcs.types.v1' queuebash.sh || fail 'vcs types JSON schema missing'
grep -q 'queuebash.vcs.detect.v1' bin/queue-vcs-detect || fail 'detect helper JSON schema missing'
grep -q 'queue vcs detect \[PATH\] \[--json\]' docs/VCS_TENANT_CONTRACT.md || fail 'VCS contract missing queue vcs detect usage'
grep -q 'queue vcs types \[--json\]' docs/VCS_TENANT_CONTRACT.md || fail 'VCS contract missing queue vcs types usage'
grep -q 'VCS tenant command JSON' README.md || fail 'README missing VCS command JSON release note'

echo "[PASS] queue vcs command JSON contract is wired"
