#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)/queue-root"

# shellcheck source=/dev/null
source "$repo_root/queuebash.sh" >/dev/null

queue submit wait-class-demo --priority 42 --class waiting -- bash -lc 'echo waiting-class' >/dev/null
job_file="$(find "$QUEUEBASH_ROOT/pending" -name '*.job' -print -quit)"
[[ -n "$job_file" && -f "$job_file" ]]
qid="$(basename "$job_file" .job)"
waiting_path="$(_queue_waiting_path_for_priority "$qid" "42" "$QUEUEBASH_ROOT")"
mkdir -p "$(dirname "$waiting_path")"
mv "$job_file" "$waiting_path"

out="$(queue list --state waiting)"
printf '%s\n' "$out"

grep -q 'JOB_ID[[:space:]]\+STATE[[:space:]]\+PRI[[:space:]]\+CLASS[[:space:]]\+NAME' <<< "$out"
grep -q "$qid" <<< "$out"
grep -q 'waiting' <<< "$out"
grep -q 'wait-class-demo' <<< "$out"
# The class value is also "waiting" and must be visible as a column, not lost
# behind the state value.  This checks the row has STATE waiting, PRI 42,
# CLASS waiting, then NAME wait-class-demo in order.
grep -Eq "${qid}[[:space:]]+waiting[[:space:]]+42[[:space:]]+waiting[[:space:]]+wait-class-demo" <<< "$out"

json="$(queue list --state waiting --json)"
printf '%s\n' "$json" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert len(d["jobs"]) == 1; j=d["jobs"][0]; assert j["state"] == "waiting"; assert j["class"] == "waiting"; assert j["name"] == "wait-class-demo"'

# Positional query/filter semantics remain separate; state filtering is explicit.
queue list --state pending | grep -q '^JOB_ID'
