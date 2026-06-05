#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -q 'fingerprint' bin/queue-vcs-probe || fail 'probe helper missing fingerprint field'
grep -q 'vcs:fingerprint' assets.d/vcs.sh || fail 'VCS asset plugin missing fingerprint facility'
grep -q 'queue_asset_check_vcs_fingerprint' assets.d/vcs.sh || fail 'VCS fingerprint asset function missing'
grep -q 'vcs:fingerprint' queuebash.sh || fail 'queue vcs types JSON missing fingerprint asset'
grep -q 'vcs:fingerprint' docs/VCS_TENANT_CONTRACT.md || fail 'VCS contract missing fingerprint asset'
bash -n bin/queue-vcs-probe || fail 'queue-vcs-probe syntax failed'
bash -n assets.d/vcs.sh || fail 'assets.d/vcs.sh syntax failed'
bash -n queuebash.sh || fail 'queuebash syntax failed'

echo "[PASS] VCS probe fingerprint contract is wired"
