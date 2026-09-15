#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/.queuebash/assets.d/sys.sh"

out_mb="$(queue_asset_check_sys_memory_available system '' min_mb=1)"
printf '%s\n' "$out_mb" | grep -q 'asset_check_ok: sys:memory_available'
printf '%s\n' "$out_mb" | grep -q 'required_mb=1'

out_gb="$(queue_asset_check_sys_memory_available system '' min_gb=0)"
printf '%s\n' "$out_gb" | grep -q 'asset_check_ok: sys:memory_available'
printf '%s\n' "$out_gb" | grep -q 'required_gb=0'

if queue_asset_check_sys_memory_available system '' min_mb=abc >/tmp/bq-sys-mem-invalid.out 2>&1; then
  echo "expected invalid min_mb to block" >&2
  exit 1
fi
grep -q 'requires min_mb parameter (numeric)' /tmp/bq-sys-mem-invalid.out

grep -q 'queue_class_shared_asset sys memory_available "system" min_mb=512' "$ROOT/.queuebash/classes/BATCH_PROCESSING.env"

echo "sys_memory_available_min_mb_smoke: ok"
