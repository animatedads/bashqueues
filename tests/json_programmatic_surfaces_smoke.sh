#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
export QUEUEBASH_ROOT="$ROOT/q"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1

runq() {
    local cmd="$1"
    timeout 30 bash -lc "cd '$PWD'; export QUEUEBASH_ROOT='$QUEUEBASH_ROOT' QUEUEBASH_ALLOW_NONINTERACTIVE=1; source ./queuebash.sh >/dev/null; $cmd"
}

submit_json="$(runq "queue submit json_probe --json -- bash -lc 'echo json-probe'")"
python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["status"]=="submitted"; assert d["qid"]; assert d["state"]=="pending"; assert d["job_file"]' "$submit_json"
qid="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["qid"])' "$submit_json")"

check_json_cmd() {
    local label="$1" cmd="$2"
    runq "$cmd" > "$ROOT/out.json"
    python3 -m json.tool "$ROOT/out.json" >/dev/null
    python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$ROOT/out.json"
    echo "[PASS] $label"
}

check_json_cmd 'queue list --json' 'queue list --json'
check_json_cmd 'queue authorisation list --json' 'queue authorisation list --json'
check_json_cmd 'queue keys list --json' 'queue keys list --json'
check_json_cmd 'queue status --json' "queue status '$qid' --json --tail 0"

[[ ! -e assets.d/net_usage.sh ]]
echo '[PASS] assets.d/net_usage.sh is absent'
