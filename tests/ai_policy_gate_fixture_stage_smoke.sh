#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
summary="$TMP/summary.jsonl"
: > "$summary"
qgate() { timeout 10 "$ROOT/bin/queue-ai-policy-gate" "$@"; }
record(){
  local stage="$1" status="$2" detail="${3:-}"
  python3 - "$summary" "$stage" "$status" "$detail" <<'PY'
import json, sys, time
path, stage, status, detail = sys.argv[1:]
with open(path, 'a', encoding='utf-8') as fh:
    fh.write(json.dumps({"schema":"queuebash.ai_policy_gate.stage_result.v1","stage":stage,"status":status,"detail":detail,"time":int(time.time())}, separators=(',', ':')) + "\n")
PY
}
fail_stage(){ record "$1" fail "$2"; cat "$summary" >&2; exit 1; }

mkdir -p "$TMP/root/pending" "$TMP/root/pol_blocked" "$TMP/root/logs"
cat > "$TMP/root/pending/job1.job" <<'JOB'
JOB_ID=job1
JOB_NAME=ordinary
JOB_CLASS=DEFAULT
PRIORITY=100
RUNNER=auto
SANDBOX_LEVEL=off
COMMAND=( echo hello )
JOB

# Stage 1: disabled-by-default failure is bounded and distinguishable.
if QUEUEBASH_ROOT="$TMP/root" qgate scan --limit 1 >"$TMP/disabled.out" 2>"$TMP/disabled.err"; then
  fail_stage disabled_default 'scan unexpectedly succeeded while gate disabled'
fi
grep -q 'disabled' "$TMP/disabled.err" || fail_stage disabled_default 'disabled diagnostic missing'
record disabled_default pass

# Stage 2: weak unsupported block request downgrades to advisory delay, not pol_block.
QUEUEBASH_AI_POLICY_GATE_ENABLED=1 QUEUEBASH_ROOT="$TMP/root" \
  qgate scan --limit 1 \
  --fixture-decision-json "$ROOT/tests/fixtures/ai_policy_gate/weak_block_downgrade_decision.json" \
  > "$TMP/delay.json" || fail_stage advisory_downgrade 'scan failed'
python3 - "$TMP/delay.json" <<'PY' || fail_stage advisory_downgrade 'json assertion failed'
import json, sys
obj=json.load(open(sys.argv[1]))
assert obj["schema"] == "queuebash.ai_policy_gate.result.v1"
assert obj["results"][0]["action"] == "advise_delay", obj
PY
[[ ! -f "$TMP/root/pol_blocked/job1.job" ]] || fail_stage advisory_downgrade 'job was policy blocked unexpectedly'
record advisory_downgrade pass

# Stage 3: low confidence unknown block request is allowed.
QUEUEBASH_AI_POLICY_GATE_ENABLED=1 QUEUEBASH_ROOT="$TMP/root" \
  qgate classify --job-file "$TMP/root/pending/job1.job" \
  --fixture-decision-json "$ROOT/tests/fixtures/ai_policy_gate/low_confidence_unknown_decision.json" \
  > "$TMP/lowconf.json" || fail_stage low_confidence_unknown 'classify failed'
python3 - "$TMP/lowconf.json" <<'PY' || fail_stage low_confidence_unknown 'json assertion failed'
import json, sys
obj=json.load(open(sys.argv[1]))
assert obj["decision"] == "allow", obj
PY
record low_confidence_unknown pass

# Stage 4: request generation redacts obvious inline secrets.
cat > "$TMP/root/pending/job3.job" <<'JOB'
JOB_ID=job3
JOB_NAME=secret-redaction
JOB_CLASS=DEFAULT
PRIORITY=100
RUNNER=auto
SANDBOX_LEVEL=off
COMMAND=( curl -H 'Authorization: Bearer abcdefghijklmnopqrstuvwxyz' --password supersecret123 https://example.invalid )
JOB
QUEUEBASH_AI_POLICY_GATE_ENABLED=1 QUEUEBASH_ROOT="$TMP/root" \
  qgate classify --job-file "$TMP/root/pending/job3.job" \
  --fixture-decision-json "$ROOT/tests/fixtures/ai_policy_gate/allow_decision.json" \
  --request-json "$TMP/request.json" >/dev/null || fail_stage redaction 'classify failed'
! grep -q 'abcdefghijklmnopqrstuvwxyz' "$TMP/request.json" || fail_stage redaction 'bearer token leaked'
! grep -q 'supersecret123' "$TMP/request.json" || fail_stage redaction 'password leaked'
grep -q '\[REDACTED' "$TMP/request.json" || fail_stage redaction 'redaction marker missing'
record redaction pass

python3 - "$summary" <<'PY'
import json, sys
rows=[json.loads(line) for line in open(sys.argv[1], encoding='utf-8') if line.strip()]
failed=[r for r in rows if r['status'] != 'pass']
out={
  "schema":"queuebash.ai_policy_gate.fixture_stage_summary.v1",
  "status":"pass" if not failed else "fail",
  "stages":len(rows),
  "passed":sum(1 for r in rows if r['status']=='pass'),
  "failed":len(failed),
  "stage_results":rows,
}
print(json.dumps(out, separators=(',', ':')))
if failed:
    raise SystemExit(1)
PY
