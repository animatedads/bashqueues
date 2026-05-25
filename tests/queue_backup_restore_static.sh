#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
grep -q '_queue_backup_create' queuebash.sh
grep -q '_queue_backup_restore' queuebash.sh
grep -q 'queue backup restore' queuebash.sh
echo '[PASS] queue backup/restore commands are wired'
