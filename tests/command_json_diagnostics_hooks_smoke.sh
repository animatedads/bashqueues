#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
cleanup(){ rm -rf "$QUEUEBASH_ROOT"; }
trap cleanup EXIT
source ./queuebash.sh
queue submit jsondiag -- echo hi >/dev/null
qid="$(queue list --json | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["jobs"][0]["qid"])')"
queue hooks "$qid" --json | python3 -c 'import sys,json; d=json.load(sys.stdin); assert d["schema"]=="queuebash.command_result.v1" and d["ok"] is True and d["command"]=="hooks" and d["matched"]==1'
queue on-success "$qid" --json -- echo ok | python3 -c 'import sys,json; d=json.load(sys.stdin); assert d["ok"] is True and d["hook"]=="ON_SUCCESS" and d["changed"]==1'
queue hooks "$qid" --json | python3 -c 'import sys,json; d=json.load(sys.stdin); assert d["jobs"][0]["on_success"]=="echo ok"'
queue pids "$qid" --json | python3 -c 'import sys,json; d=json.load(sys.stdin); assert d["ok"] is True and d["command"] in ("pids","pid","ps") and d["matched"]==1 and "run_pid" in d["jobs"][0]'
set +e
metrics_out="$(queue metrics "$qid" --json)"
metrics_rc=$?
set -e
printf '%s' "$metrics_out" | python3 -c 'import sys,json; d=json.load(sys.stdin); assert d["schema"]=="queuebash.command_result.v1" and d["command"] in ("metrics","metric","unit") and d["error"]["code"]=="no_systemd_unit"'
test "$metrics_rc" -eq 1
queue on-failure "$qid" --dryrun --json -- echo fail | python3 -c 'import sys,json; d=json.load(sys.stdin); assert d["ok"] is True and d["dryrun"] is True and d["changed"]==0 and d["jobs"][0]["action"]=="would_update"'

echo "PASS command_json_diagnostics_hooks_smoke"
