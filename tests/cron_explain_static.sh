#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

grep -q '_queue_cron_explain_file' queuebash.sh
grep -Fq 'explain [user|--all|system]' queuebash.sh
grep -q 'one queue job per matching minute' queuebash.sh
grep -q 'unsupported macro @reboot' queuebash.sh
grep -q 'QUEUEBASH_SELECTED_USER' queuebash.sh

echo "[PASS] cron explain and selected-user scoped cron list are wired"
