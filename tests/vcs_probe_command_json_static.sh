#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -q 'queue vcs probe \[PATH\] \[--json\] \[--type TYPE\] \[--timeout SECONDS\]' queuebash.sh || fail 'queue vcs probe usage missing from command help'
grep -q 'queue-vcs-probe' queuebash.sh || fail 'queue vcs probe helper dispatch missing'
grep -q 'VCS_CHANGESET_AUDIT' queuebash.sh || fail 'queue vcs types JSON missing VCS_CHANGESET_AUDIT'
grep -q 'vcs:identity' queuebash.sh || fail 'queue vcs types JSON missing identity asset'
grep -q 'vcs:revision' queuebash.sh || fail 'queue vcs types JSON missing revision asset'
grep -q 'queue vcs probe \[PATH\] \[--json\] \[--type TYPE\] \[--timeout SECONDS\]' docs/VCS_TENANT_CONTRACT.md || fail 'contract missing queue vcs probe usage'
grep -q 'queue vcs probe \[PATH\] \[--json\] \[--type TYPE\] \[--timeout SECONDS\]' resources.d/display/lang_eng/vcs-help.txt || fail 'display help missing queue vcs probe usage'
bash -n queuebash.sh || fail 'queuebash syntax failed'
bash -n assets.d/vcs.sh || fail 'assets.d/vcs.sh syntax failed'
bash -n bin/queue-vcs-probe || fail 'queue-vcs-probe syntax failed'

echo "[PASS] queue vcs probe command contract is wired"
