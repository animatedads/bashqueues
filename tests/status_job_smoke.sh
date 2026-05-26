#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
trap 'rm -rf "$QUEUEBASH_ROOT"' EXIT

source ./queuebash.sh
out="$(queue submit stat_smoke -- bash -lc 'echo status-payload')"
qid="$(printf '%s\n' "$out" | awk '{print $2; exit}')"
queue run >/dev/null 2>&1

text="$(queue status "$qid" --tail 10)"
grep -q "QUEUEBASH STATUS: $qid" <<< "$text"
grep -q 'state:.*done' <<< "$text"
grep -q 'command:.*status-payload' <<< "$text"
grep -q 'status-payload' <<< "$text"

json="$(queue status "$qid" --json --tail 10)"
python3 - <<'PY' <<< "$json"
import json, sys
obj = json.loads(sys.stdin.read())
assert obj["qid"]
assert obj["state"] == "done"
assert obj["class"] == "DEFAULT"
assert "status-payload" in obj["command_line"]
assert "status-payload" in obj["log"]["tail"]
assert "run_pid" in obj["pids"]
assert obj["rc"] == "0"
PY

[[ ! -d "$QUEUEBASH_ROOT/policy_blocked" ]]

echo "[PASS] queue status text/json summaries include job details and tail"
