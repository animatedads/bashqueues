#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
q="$root_dir/queuebash.sh"
installer="$root_dir/install-system.sh"

grep -q 'chmod 1777 /var/spool/bashqueues_cron' "$installer"
grep -q 'install -d -m 1777 /var/spool/bashqueues_cron' "$installer"
grep -q 'queue cron edit: cannot write bashqueues crontab' "$q"
grep -q 'only root may edit another user' "$q"
grep -q 'expected user spool directory mode is 1777' "$q"

echo '[PASS] cron edit reports permission failures and installer fixes user spool permissions'
