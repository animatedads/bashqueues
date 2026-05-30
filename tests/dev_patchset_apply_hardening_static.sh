#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

grep -q 'queue dev patchset apply --patchset ZIP' queuebash.sh
grep -q 'ready_scratchpad_item_merge' queuebash.sh
grep -q 'backup_manifest.json' queuebash.sh
grep -q 'scratchpad will merge by item id' queuebash.sh
grep -q 'QUEUE_DEV_PATCHSET_APPLY_HARDENING' docs/QUEUE_DEV_PATCHSET_APPLY_HARDENING.md

echo "PASS dev_patchset_apply_hardening_static"
