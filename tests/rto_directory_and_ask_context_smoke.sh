#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

[[ -d RTO ]]
[[ -f RTO/README_RTO_V66_PLAN_ACTIONABILITY_PREFLIGHT_RECEIPTS.md ]]
[[ -x RTO/rto ]]

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d /tmp/queuebash-rto-ask.XXXXXX)"
# shellcheck disable=SC1091
source ./queuebash.sh >/dev/null
# queuebash is designed to be sourced into operator shells; avoid set -e altering function control flow.
set +e

out="$QUEUEBASH_ROOT/rto-ask.json"
queue ask --context rto --json 'plan a windows vm deployment with preflight receipts using rto' > "$out"
python3 - "$out" <<'PY'
import json, sys
p=sys.argv[1]
j=json.load(open(p))
assert j["schema"] == "queuebash.ai_advisory.request.v1"
r=j.get("rto") or {}
assert r.get("available") is True, r
assert r.get("relevant") is True, r
assert r.get("release") == "v66_plan_actionability_preflight_receipts", r
ctx=j.get("dynamic_context_text", "")
assert "RTO advisory context" in ctx
assert "rto plan preflight latest --json" in ctx
PY

human="$QUEUEBASH_ROOT/rto-ask.txt"
queue ask --context rto 'plan a windows vm deployment with preflight receipts using rto' > "$human"
grep -F 'rto available:    yes' "$human" >/dev/null
grep -F 'rto relevant:     yes' "$human" >/dev/null
grep -F 'rto preflight:' "$human" >/dev/null
