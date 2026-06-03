#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

require() {
    local pattern="$1" label="$2"
    if ! grep -Eq -- "$pattern" queuebash.sh; then
        echo "[FAIL] missing: $label" >&2
        exit 1
    fi
    echo "[PASS] $label"
}

require '_queue_print_job_table_json' 'queue list JSON emitter exists'
require '_queue_classes_list_json' 'classes JSON emitter exists'
require '_queue_assets_list_json' 'assets JSON emitter exists'
require '_queue_caps_list_json' 'caps JSON emitter exists'
require '_queue_authorisation_list_json' 'authorisation JSON emitter exists'
require '_queue_authorisation_keys_list_json' 'keys JSON emitter exists'
require '_queue_submit_json_result' 'submit JSON emitter exists'
require 'queue explain <qid-or-exact-job-name> \[--json\]' 'explain JSON usage is advertised'

[[ ! -e assets.d/net_usage.sh ]] || { echo '[FAIL] assets.d/net_usage.sh returned' >&2; exit 1; }
echo '[PASS] assets.d/net_usage.sh is absent'
