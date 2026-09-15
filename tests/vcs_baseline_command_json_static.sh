#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

[[ -x bin/queue-vcs-baseline ]] || fail 'queue-vcs-baseline helper missing or not executable'
bash -n bin/queue-vcs-baseline || fail 'queue-vcs-baseline syntax failed'
bash -n bin/queue-vcs-probe || fail 'queue-vcs-probe syntax failed'
bash -n queuebash.sh || fail 'queuebash syntax failed'

grep -q 'queuebash.vcs.baseline.v1' bin/queue-vcs-baseline || fail 'baseline helper missing JSON schema'
grep -q 'QUEUEBASH_VCS_AUDIT_FINGERPRINT' bin/queue-vcs-baseline || fail 'baseline helper missing audit fingerprint export'
grep -q 'queue-vcs-baseline' queuebash.sh || fail 'queue command surface missing baseline helper'
grep -q 'baseline|capture-baseline|capture_baseline' queuebash.sh || fail 'queue vcs baseline aliases missing'
grep -q '"helpers":\["queue-vcs-detect","queue-vcs-probe","queue-vcs-assert","queue-vcs-baseline"\]' queuebash.sh || fail 'queue vcs types JSON missing baseline helper metadata'
grep -q 'queuebash.vcs.baseline.v1' resources.d/display/lang_eng/vcs-help.txt || fail 'display help missing baseline JSON schema'
grep -q 'cvs_metadata_only' bin/queue-vcs-probe || fail 'CVS probe not marked metadata-only'
if grep -n 'cvs -n update' bin/queue-vcs-probe >/tmp/bq-vcs-probe-cvs-update.lines; then
  fail 'queue-vcs-probe must not run cvs -n update; use vcs:clean_tree for live CVS cleanliness'
fi

echo '[PASS] VCS baseline command JSON static contract present'
