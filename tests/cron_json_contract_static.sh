#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Bob23 guard: cron JSON contract helpers and dispatch branches must be present.
grep -q 'queuebash.cron.status.v1' queuebash.sh
grep -q 'queuebash.cron.list.v1' queuebash.sh
grep -q 'queuebash.cron.explain.v1' queuebash.sh
grep -q '_queue_cron_status_json' queuebash.sh
grep -q '_queue_cron_list_json' queuebash.sh
grep -q '_queue_cron_explain_json' queuebash.sh
grep -q 'security_preview' queuebash.sh
grep -q 'queue cron status --json' tests/cron_json_contract_smoke.sh
grep -q 'queue cron list --json' tests/cron_json_contract_smoke.sh
grep -q 'queue cron explain.*--json' tests/cron_json_contract_smoke.sh
echo 'PASS cron_json_contract_static'
