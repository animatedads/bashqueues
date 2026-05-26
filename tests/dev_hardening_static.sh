#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

grep -q '_queue_dev_lock()' queuebash.sh
grep -q '_queue_dev_unlock()' queuebash.sh
grep -q '_queue_dev_prune_backups()' queuebash.sh
grep -q 'flock -w' queuebash.sh
grep -q 'locked":true,"atomic":true' queuebash.sh
grep -q 'QUEUEBASH_DEV_MAX_BACKUPS' queuebash.sh
grep -q 'file_function' queuebash.sh
grep -q 'callees' queuebash.sh
grep -q 'fcntl.flock' queuemgr_panel.py
grep -q 'os.replace' queuemgr_panel.py
grep -q 'QUEUEBASH_DEV_MAX_BACKUPS' queuemgr_panel.py

echo '[PASS] queue dev hardening static checks present'
