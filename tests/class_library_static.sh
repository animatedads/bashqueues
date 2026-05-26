#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -Eq 'QUEUEBASH_VERSION="0\.[0-9]+\.[0-9]+"' queuebash.sh || fail "version not shaped"

classes=(
  ALERT_NOTIFICATION BACKUP_JOB BATCH_PROCESSING DB_MIGRATION DEADLINE_CRITICAL
  DEPLOY_RELEASE FILE_TRANSFER INTERACTIVE_PRIORITY LOG_HOUSEKEEPING
  REPORT_GENERATION SENSITIVE_DATA_EXPORT
)
for c in "${classes[@]}"; do
  f="classes/$c.env"
  [[ -f "$f" ]] || fail "missing class $f"
  bash -n "$f" || fail "class syntax failed: $f"
  grep -q "^# bashqueues class: $c" "$f" || fail "class header missing for $c"
done

grep -q 'net allowance' classes/FILE_TRANSFER.env || fail "FILE_TRANSFER must use canonical net allowance asset"
[[ ! -e assets.d/net_usage.sh ]] || fail "assets.d/net_usage.sh must remain absent"

echo "[PASS] class library files are present and syntactically valid"
