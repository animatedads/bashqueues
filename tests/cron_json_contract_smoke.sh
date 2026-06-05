#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
export QUEUEBASH_CRON_SPOOL_DIR="$(mktemp -d)"
export QUEUEBASH_CRON_SYSTEM_DIR="$(mktemp -d)"
export QUEUEBASH_CRON_STATE_DIR="$(mktemp -d)"
trap 'rm -rf "$QUEUEBASH_ROOT" "$QUEUEBASH_CRON_SPOOL_DIR" "$QUEUEBASH_CRON_SYSTEM_DIR" "$QUEUEBASH_CRON_STATE_DIR"' EXIT
printf '# bashqueues-class DEFAULT\n* * * * * echo cron-hi\n' > "$QUEUEBASH_CRON_SPOOL_DIR/$(id -un)"
source ./queuebash.sh
queue cron status --json > /tmp/cron-status.json
queue cron list --json > /tmp/cron-list.json
queue cron explain "$(id -un)" --json > /tmp/cron-explain.json
python3 - <<'PY'
import json
for path, schema in [('/tmp/cron-status.json','queuebash.cron.status.v1'),('/tmp/cron-list.json','queuebash.cron.list.v1'),('/tmp/cron-explain.json','queuebash.cron.explain.v1')]:
    data=json.load(open(path))
    assert data['schema']==schema, (path,data)
ex=json.load(open('/tmp/cron-explain.json'))
entry=ex['files'][0]['entries'][0]
preview=entry['security_preview']
for key in ['sandbox','caps','runner','working_directory','policy_source','network_warning','shell_warning']:
    assert key in preview, preview
PY
echo 'PASS cron_json_contract_smoke'
