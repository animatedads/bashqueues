#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

grep -q '^_queue_dev_lock()' queuebash.sh
grep -q '^_queue_dev_unlock()' queuebash.sh
grep -q '^_queue_dev_prune_backups()' queuebash.sh
grep -q '^_queue_dev_backup_verify()' queuebash.sh
grep -q 'flock -w' queuebash.sh
grep -q 'mv -- "$tmp" "$file"' queuebash.sh
grep -q 'locked":true' queuebash.sh
grep -q 'atomic":true' queuebash.sh
grep -q 'fcntl.flock' queuemgr_panel.py
grep -q 'os.replace' queuemgr_panel.py

echo '[PASS] queue dev locking/atomic hardening surface is present'
